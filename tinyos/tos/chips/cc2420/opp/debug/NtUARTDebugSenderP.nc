#include "ntDebug.h"

module NtUARTDebugSenderP {
    provides {
        interface NtDebug;
    }
    uses {
        interface Boot;
  		interface SplitControl as SerialControl;        
        interface Pool<message_t> as MessagePool;
        interface Queue<message_t*> as SendQueue;
        interface AMSend as UARTSendDebug;
        interface AMSend as UARTSendDump;
        interface Packet;
        interface Leds;
    }
} 
implementation {
    message_t uartPacket;
    bool sending;
    uint16_t statLogReceived;
    bool on;
 
    event void Boot.booted() {
        sending = FALSE;
        statLogReceived = 0;
        on = FALSE;
		call SerialControl.start();        
    }

  	event void SerialControl.startDone(error_t err) {
  		if( err != SUCCESS ){call SerialControl.start();}
  		else{
  			on = TRUE;
  		}	
  	}

  	event void SerialControl.stopDone(error_t err) { on = FALSE; }	
  
    task void sendTask() {
        if( !on ){
			return;
        } else if (sending) {
            return;
        } else if (call SendQueue.empty()) {
            return;
        } else {
            message_t* smsg = call SendQueue.head();
            uint8_t len = call Packet.payloadLength(smsg);
			error_t eval = FAIL;
            if( len == sizeof(NtDebugMsg_t) ){
            	eval = call UARTSendDebug.send(AM_BROADCAST_ADDR, smsg, len);  
            } else if( len == sizeof(NtDebugDumpMsg_t) ){
            	eval = call UARTSendDump.send(AM_BROADCAST_ADDR, smsg, len);  
            }             
            if (eval == SUCCESS) {
                sending = TRUE;
                return;
            } else {
                //Drop packet. Don't retry.
                call SendQueue.dequeue();
                call MessagePool.put(smsg);
                if (! call SendQueue.empty())
                    post sendTask();
            }
        }
    }

    event void UARTSendDebug.sendDone(message_t *msg, error_t error) {
        message_t* qh = call SendQueue.head();
        if (qh == NULL || qh != msg) {
            //bad mojo
            return;
        }
        call SendQueue.dequeue();
        call MessagePool.put(msg);  
        sending = FALSE;
        if (!call SendQueue.empty()) 
            post sendTask();
    }

    event void UARTSendDump.sendDone(message_t *msg, error_t error) {
        message_t* qh = call SendQueue.head();
        if (qh == NULL || qh != msg) {
            //bad mojo
            return;
        } 
        call SendQueue.dequeue();
        call MessagePool.put(msg);  
        sending = FALSE;
        if (!call SendQueue.empty()) 
            post sendTask();
    }

	error_t enqueue(message_t* msg){
        if (call SendQueue.enqueue(msg) == SUCCESS) {
            post sendTask();
            return SUCCESS;
        } else {
            call MessagePool.put(msg);
            return FAIL;
        }
	}
	
	error_t buildDebugMsg( uint8_t type, uint8_t edc, uint8_t nextHopEdc, uint8_t indexesInUse, uint8_t indexes, uint32_t avgDc, uint32_t txTime, uint32_t timestamp){
		message_t* msg = call MessagePool.get();
        NtDebugMsg_t* dbg_msg = call UARTSendDebug.getPayload(msg, sizeof(NtDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
		dbg_msg->type = type;
		dbg_msg->edc = edc;
		dbg_msg->nextHopEdc = nextHopEdc;
		dbg_msg->indexesInUse = indexesInUse;
		dbg_msg->indexes = indexes;
		dbg_msg->avgDc = avgDc;		
		dbg_msg->seqNum = statLogReceived;
		dbg_msg->txTime = txTime;		
		dbg_msg->timestamp = timestamp;
		call Packet.setPayloadLength(msg, sizeof(NtDebugMsg_t));
		return enqueue(msg); 
	}

	error_t buildDumpMsg(uint8_t dumpNum, nbTableEntry_t* nbTable, uint8_t* p){
		message_t* msg = call MessagePool.get();
        NtDebugDumpMsg_t* dbg_msg = call UARTSendDump.getPayload(msg, sizeof(NtDebugDumpMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
	    dbg_msg->seqNum = statLogReceived;
		dbg_msg->dumpNum = dumpNum;

		dbg_msg->ntEntry0.addr = nbTable[0 + dumpNum * NT_ENTRIES_PER_DUMP].addr;
		dbg_msg->ntEntry0.count = nbTable[0 + dumpNum * NT_ENTRIES_PER_DUMP].count;
		dbg_msg->ntEntry0.edc = nbTable[0 + dumpNum * NT_ENTRIES_PER_DUMP].edc;
		dbg_msg->ntEntry0.p = p[0 + dumpNum * NT_ENTRIES_PER_DUMP];

		dbg_msg->ntEntry1.addr = nbTable[1 + dumpNum * NT_ENTRIES_PER_DUMP].addr;
		dbg_msg->ntEntry1.count = nbTable[1 + dumpNum * NT_ENTRIES_PER_DUMP].count;
		dbg_msg->ntEntry1.edc = nbTable[1 + dumpNum * NT_ENTRIES_PER_DUMP].edc;
		dbg_msg->ntEntry1.p = p[1 + dumpNum * NT_ENTRIES_PER_DUMP];

		dbg_msg->ntEntry2.addr = nbTable[2 + dumpNum * NT_ENTRIES_PER_DUMP].addr;
		dbg_msg->ntEntry2.count = nbTable[2 + dumpNum * NT_ENTRIES_PER_DUMP].count;
		dbg_msg->ntEntry2.edc = nbTable[2 + dumpNum * NT_ENTRIES_PER_DUMP].edc;
		dbg_msg->ntEntry2.p = p[2 + dumpNum * NT_ENTRIES_PER_DUMP];

		dbg_msg->ntEntry3.addr = nbTable[3 + dumpNum * NT_ENTRIES_PER_DUMP].addr;
		dbg_msg->ntEntry3.count = nbTable[3 + dumpNum * NT_ENTRIES_PER_DUMP].count;
		dbg_msg->ntEntry3.edc = nbTable[3 + dumpNum * NT_ENTRIES_PER_DUMP].edc;
		dbg_msg->ntEntry3.p = p[3 + dumpNum * NT_ENTRIES_PER_DUMP];

		dbg_msg->ntEntry4.addr = nbTable[4 + dumpNum * NT_ENTRIES_PER_DUMP].addr;
		dbg_msg->ntEntry4.count = nbTable[4 + dumpNum * NT_ENTRIES_PER_DUMP].count;
		dbg_msg->ntEntry4.edc = nbTable[4 + dumpNum * NT_ENTRIES_PER_DUMP].edc;
		dbg_msg->ntEntry4.p = p[4 + dumpNum * NT_ENTRIES_PER_DUMP];

		call Packet.setPayloadLength(msg, sizeof(NtDebugDumpMsg_t) );
		return enqueue(msg); 
	}

	command error_t NtDebug.dumpTable(nbTableEntry_t* nbTable, uint8_t* p, uint8_t type, uint8_t edc, uint8_t nextHopEdc, uint8_t indexesInUse, uint8_t indexes, uint32_t avgDc, uint32_t txTime, uint32_t timestamp){
        statLogReceived++;
		if( call MessagePool.size() < 1 + NT_DUMP_MSG_COUNT){
            return FAIL;
		} else {
			int i;
			error_t ret = buildDebugMsg( type, edc, nextHopEdc, indexesInUse, indexes, avgDc, txTime, timestamp);
			if (ret != SUCCESS ) return ret;
			for( i = 0; i < NT_DUMP_MSG_COUNT; i++ ){			
				ret =  buildDumpMsg(i, nbTable, p);    		
				if (ret != SUCCESS ) return ret;
			}
		} 
		return SUCCESS;
	}
}
    
