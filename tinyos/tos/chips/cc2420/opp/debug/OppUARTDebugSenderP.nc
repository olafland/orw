#include "oppDebug.h"

module OppUARTDebugSenderP {
    provides {
        interface OppDebug;
    }
    uses {
        interface Boot;
  		interface SplitControl as SerialControl;        
        interface Pool<message_t> as MessagePool;
        interface Queue<message_t*> as SendQueue;
        interface AMSend as UARTSend;
    }
} 
implementation {
    message_t uartPacket;
    bool sending;
    uint8_t len;
    uint16_t statLogReceived = 0;
    

    event void Boot.booted() {
        sending = FALSE;
        len = sizeof(OppDebugMsg_t);
        statLogReceived = 0;
		call SerialControl.start();        
    }

  	event void SerialControl.startDone(error_t err) {
  		if( err != SUCCESS ){call SerialControl.start();}  		
  	}

  	event void SerialControl.stopDone(error_t err) {}	
  
    task void sendTask() {
        if (sending) {
            return;
        } else if (call SendQueue.empty()) {
            return;
        } else {
            message_t* smsg = call SendQueue.head();
            error_t eval = call UARTSend.send(AM_BROADCAST_ADDR, smsg, len);
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

    event void UARTSend.sendDone(message_t *msg, error_t error) {
        message_t* qh = call SendQueue.head();
        if (qh == NULL || qh != msg) {
            //bad mojo
        } else {
            call SendQueue.dequeue();
            call MessagePool.put(msg);  
        }
        sending = FALSE;
        if (!call SendQueue.empty()) 
            post sendTask();
    }

    command error_t OppDebug.logEvent(uint8_t type) {
        statLogReceived++;
        if (call MessagePool.empty()) {
            return FAIL;
        } else {
            message_t* msg = call MessagePool.get();
            OppDebugMsg_t* dbg_msg = call UARTSend.getPayload(msg, sizeof(OppDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
	    
            memset(dbg_msg, 0, len);

            dbg_msg->type = type;
            dbg_msg->seqno = statLogReceived;

            if (call SendQueue.enqueue(msg) == SUCCESS) {
                post sendTask();
                return SUCCESS;
            } else {
                call MessagePool.put(msg);
                return FAIL;
            }
        }
    }
    /* Used for FE_SENT_MSG, FE_RCV_MSG, FE_FWD_MSG, FE_DST_MSG */
    command error_t TRUSTEDBLOCK OppDebug.logEventMsg(uint8_t type, uint16_t msg_id, am_addr_t origin, am_addr_t node) {
        statLogReceived++;
        if (call MessagePool.empty()) {
            return FAIL;
        } else {
            message_t* msg = call MessagePool.get();
            OppDebugMsg_t* dbg_msg = call UARTSend.getPayload(msg, sizeof(OppDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
            memset(dbg_msg, 0, len);

            dbg_msg->type = type;
            dbg_msg->data.msg.msg_uid = msg_id;
            dbg_msg->data.msg.origin = origin;
            dbg_msg->data.msg.other_node = node;
            dbg_msg->seqno = statLogReceived;

            if (call SendQueue.enqueue(msg) == SUCCESS) {
                post sendTask();
                return SUCCESS;
            } else {
                call MessagePool.put(msg);
                return FAIL;
            }
        }
    }
    /* Used for TREE_NEW_PARENT, TREE_ROUTE_INFO */
    command error_t TRUSTEDBLOCK OppDebug.logEventRoute(uint8_t type, am_addr_t parent, uint8_t hopcount, uint16_t metric) {
        statLogReceived++;
        if (call MessagePool.empty()) {
            return FAIL;
        } else {
            message_t* msg = call MessagePool.get();
            OppDebugMsg_t* dbg_msg = call UARTSend.getPayload(msg, sizeof(OppDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
            memset(dbg_msg, 0, len);

            dbg_msg->type = type;
            dbg_msg->data.route_info.parent = parent;
            dbg_msg->data.route_info.hopcount = hopcount;
            dbg_msg->data.route_info.metric = metric;
            dbg_msg->seqno = statLogReceived;

            if (call SendQueue.enqueue(msg) == SUCCESS) {
                post sendTask();
                return SUCCESS;
            } else {
                call MessagePool.put(msg);
                return FAIL;
            }
        }
    }
    /* Used for DBG_1 */ 
    command error_t OppDebug.logEventSimple(uint8_t type, uint16_t arg) {
        statLogReceived++;
        if (call MessagePool.empty()) {
            return FAIL;
        } else {
            message_t* msg = call MessagePool.get();
            OppDebugMsg_t* dbg_msg = call UARTSend.getPayload(msg, sizeof(OppDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
            memset(dbg_msg, 0, len);

            dbg_msg->type = type;
            dbg_msg->data.arg = arg;
            dbg_msg->seqno = statLogReceived;

            if (call SendQueue.enqueue(msg) == SUCCESS) {
                post sendTask();
                return SUCCESS;
            } else {
                call MessagePool.put(msg);
                return FAIL;
            }
        }
    }
    /* Used for DBG_2, DBG_3 */
    command TRUSTEDBLOCK error_t OppDebug.logEventDbg(uint8_t type, uint16_t arg1, uint16_t arg2, uint16_t arg3) {
        statLogReceived++;
        if (call MessagePool.empty()) {
            return FAIL;
        } else {
            message_t* msg = call MessagePool.get();
            OppDebugMsg_t* dbg_msg = call UARTSend.getPayload(msg, sizeof(OppDebugMsg_t));
	    if (dbg_msg == NULL) {
	      return FAIL;
	    }
            memset(dbg_msg, 0, len);

            dbg_msg->type = type;
            dbg_msg->data.dbg.a = arg1;
            dbg_msg->data.dbg.b = arg2;
            dbg_msg->data.dbg.c = arg3;
            dbg_msg->seqno = statLogReceived;

            if (call SendQueue.enqueue(msg) == SUCCESS) {
                post sendTask();
                return SUCCESS;
            } else {
                call MessagePool.put(msg);
                return FAIL;
            }
        }
    }

}
    
