/*
 * Copyright (c) 2012-2013 Olaf Landsiedel
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Arch Rock Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * ARCHED ROCK OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 *
 * @author Olaf Landsiedel
 */
 
#include "opp.h"

module OppP{

	provides interface Opp;
	provides interface Send;
	provides interface Packet;
	provides interface Init;
	provides interface Receive;
	provides interface SplitControl as Control;
	
	uses interface Leds;
	uses interface AMSend as SubSend;
	uses interface Packet as SubPacket;
	uses interface Receive as SubReceive;
	uses interface Receive as SubDupReceive;
	uses interface Queue<message_t> as MsgQueue;
	uses interface PacketAcknowledgements;
	uses interface OppPacket;
	uses interface OppDebug;
	uses interface AMPacket;
	uses interface SplitControl as SubControl;
    uses interface LowPowerListening;
    uses interface NbTable;
    uses interface Timer<TMilli>;
    uses interface Random;
    uses interface Unique;
    uses interface TxTime;
    uses interface Timer<TMilli> as TxTimer;
	
} 
implementation {
	//split control still missing
	
	uint16_t seqNum;
	message_t currentMsg;
	message_t* currentMsgPtr;
	message_t* appMsgPtr;
	message_t* dummyMsgPtr;	
	uint8_t msgNextHopEtx;
	uint32_t txStartTime;
	uint8_t txCount;
	bool queueFull;

//	uint8_t getMyEtx();
//	uint8_t getExpectedNextHopEtx();
	void send();
	error_t sendOrEnqueue();
	uint8_t getEtx(am_addr_t addr);
	uint8_t getSourceEtx(am_addr_t addr);
	uint16_t setAddr(uint8_t etx, uint8_t ownEtx);
	
	void logSent(message_t* msg);
 	void logSentFail(message_t* msg);
	void logReceive(message_t* msg);
 	void logMediumBusy(message_t* msg);
 	void logAppSent(message_t* msg);
 		
	task void logQueueFull_task();
	task void send_task();
	
	uint8_t incSeqNum(){
		seqNum++;
		if( seqNum == OPP_DUMMY_SEQ_NUM ){
			seqNum = OPP_DUMMY_SEQ_NUM + 1;
		}
		return seqNum;
	} 
		
	command error_t Init.init() {
    	seqNum = 0;
    	currentMsgPtr = NULL;
    	appMsgPtr = NULL;
    	dummyMsgPtr = NULL;
    	atomic queueFull = FALSE;
    	return SUCCESS;
  	}

	bool checkQueue(){
		if (queueFull){
			post logQueueFull_task();
		}
	  	return queueFull;	
	}

	async command bool Opp.acceptMsg( uint16_t etxPack ){
		uint8_t etx = getEtx(etxPack);
		return ( call NbTable.getMyEdc() <= etx && call NbTable.getMyEdc() < OPP_INVALID_EDC 
			&& etx <= OPP_INVALID_EDC && !checkQueue() );
	}
 
   	async command void Opp.update(uint16_t etx, am_addr_t src, bool accept){
		call NbTable.update( src, getSourceEtx(etx), accept );
   	}

	command error_t Send.send(message_t* msg, uint8_t len){
	    if( appMsgPtr != NULL ) {return EBUSY;}
	    if( len > call Send.maxPayloadLength() ) {return ESIZE;} 
	    if( TOS_NODE_ID == SINK_ID ) {return FAIL;}	    	    

    	//LPL will enable packet acks
    	call Packet.setPayloadLength(msg, len);
 		call OppPacket.init(msg, TOS_NODE_ID, incSeqNum(), 0, FALSE);
		logAppSent(msg);
		appMsgPtr = msg;	  
		call LowPowerListening.setRemoteWakeupInterval(appMsgPtr, LPL_DEF_REMOTE_WAKEUP);		  	    
		send();
		return SUCCESS;
  	}
  
  	command error_t Send.cancel(message_t* msg){
  		return FAIL;
  	}
  
	command uint8_t Send.maxPayloadLength(){
		return call Packet.maxPayloadLength();	
	}
	
	command void* Send.getPayload(message_t* msg, uint8_t len){
 		return call Packet.getPayload(msg, len);
 	}	
	
	event void SubSend.sendDone(message_t* msg, error_t error){
		//TODO: add retry counter		
		//TODO: add support for sending bc messages: no we do not want this
		if( msg == currentMsgPtr ){
			if( error == SUCCESS ){
				uint32_t txTime = call Timer.getNow() - txStartTime + txCount * LPL_DEF_REMOTE_WAKEUP;
				if( call OppPacket.getSeqNum(msg) != OPP_DUMMY_SEQ_NUM ){
					if( call PacketAcknowledgements.wasAcked(msg) ){
						currentMsgPtr = NULL;
						logSent(msg);
						call NbTable.txEnd(TX_SUCCESS, txTime);
						if( msg == appMsgPtr ){
							appMsgPtr = NULL;
							signal Send.sendDone(msg, error);		
						}		
						post send_task();
					} else {
						txCount++;
						if( txCount < call NbTable.getMaxTxDc() ){
							//expected, try again, no penalities
							call NbTable.txEnd(TX_HOLD, txTime);					
						} else {
							//fail: need penalty for neighhor table, initiate pull
							logSentFail(msg);
							call OppPacket.setPull(currentMsgPtr, TRUE);		
							call NbTable.txEnd(TX_FAIL, txTime);
						}
						call Timer.startOneShot( OPP_RETX_OFFSET + (call Random.rand32() % OPP_RETX_WINDOW) );
					}
				} else {
					//dummy msg
					if(call LowPowerListening.getRemoteWakeupInterval(msg) != 0 ){
						if( call PacketAcknowledgements.wasAcked(msg) || call NbTable.getMyEdc() < OPP_INVALID_EDC ){
							call NbTable.txEnd(TX_SUCCESS, txTime);
							logSent(msg);
							currentMsgPtr = NULL;
							dummyMsgPtr = NULL;
							post send_task();
						} else {						
							//was duty cycled pull dummy message and we still have invalid EDC nor did we get acked: retransmit
							txCount++;
							call NbTable.txEnd(TX_FAIL, txTime);
							logSentFail(msg);
							if( appMsgPtr == NULL && call MsgQueue.empty() ){
								//only retransmit if there nothing else to send
								call Timer.startOneShot( OPP_RETX_DUMMY_OFFSET + (call Random.rand32() % OPP_RETX_DUMMY_WINDOW) );
							} else {
								//otherwise, just call send, we do not need the dummy anymore
								currentMsgPtr = NULL;
								dummyMsgPtr = NULL;
								post send_task();
							}
						}
					} else {
						//simple one shot probe-reply, no reason to log or update timings..
						currentMsgPtr = NULL;
						dummyMsgPtr = NULL;
						post send_task();
					}
				}
			} else {
				//medium was busy or so: just log and retransmit
				logMediumBusy(msg);
				call Timer.startOneShot( OPP_TXFAIL_OFFSET + (call Random.rand32() % OPP_TXFAIL_WINDOW) );
			}
		}		
	}
	
	event void Timer.fired(){
		//TODO error handling
		txStartTime = call Timer.getNow();
		if( call OppPacket.getSeqNum(currentMsgPtr) != 0 ){
			call SubSend.send( setAddr(call NbTable.getNextHopEdc(), call NbTable.getMyEdc()) , currentMsgPtr, call SubPacket.payloadLength(currentMsgPtr));
		} else {
			if( call NbTable.getMyEdc() >= OPP_INVALID_EDC + 1 ){
				call SubSend.send( setAddr(call NbTable.getNextHopEdc(), call NbTable.getMyEdc()) , currentMsgPtr, call SubPacket.payloadLength(currentMsgPtr));				
			} else {
				uint32_t txTime = call Timer.getNow() - txStartTime + txCount * LPL_DEF_REMOTE_WAKEUP;
				call NbTable.txEnd(TX_SUCCESS, txTime);
				logSent(currentMsgPtr);
				currentMsgPtr = NULL;
				dummyMsgPtr = NULL;
				send();
			}
		}
	}
	
	void sendDummyMsg(bool pull, bool dc){
		if( appMsgPtr == NULL && currentMsgPtr == NULL && dummyMsgPtr == NULL && call MsgQueue.empty() ){
	    	call Packet.setPayloadLength(&currentMsg, 0);
	 		call OppPacket.init(&currentMsg, TOS_NODE_ID, OPP_DUMMY_SEQ_NUM, MAX_TTL, pull);	 		
	 		if( dc ){
				call LowPowerListening.setRemoteWakeupInterval(&currentMsg, LPL_DEF_REMOTE_WAKEUP);
			} else {
				call LowPowerListening.setRemoteWakeupInterval(&currentMsg, 0);
			}
			dummyMsgPtr = &currentMsg;
			post send_task();
		}
	}

	void sendDataDummyMsg(){
		sendDummyMsg(FALSE, FALSE);
	}

	void sendPullMsg(){
		sendDummyMsg(TRUE, TRUE);
	}
	
	//void sendUpdateMsg(){
	//	sendDummyMsg(FALSE, TRUE);
	//}
	
	command void Opp.pull(uint16_t msgSource, uint8_t msgDsn){
		//only called when not accepted
		if( call Unique.checkAndAdd(msgSource, msgDsn) ){
			if( call NbTable.getMyEdc() >= OPP_INVALID_EDC + 1 ){
				sendPullMsg();
			} else {
				sendDataDummyMsg();
			}
		}		
	}
	
	event message_t* SubReceive.receive(message_t *msg, void *payload, uint8_t len){
		opp_header_t* oppHeader = (opp_header_t*) payload;
		logReceive(msg);
		if( oppHeader->seqNum == OPP_DUMMY_SEQ_NUM ){
			//dummy msg
			if( oppHeader->pull ){
				sendDataDummyMsg();
			}
			return msg;
		}
		if( TOS_NODE_ID == SINK_ID ){
			sendDataDummyMsg();
			return signal Receive.receive(msg, payload, len);
		}
		if( oppHeader->ttl >= MAX_TTL ){ 
			return msg;
		}
		oppHeader->ttl++;
		oppHeader->pull = FALSE;
		call LowPowerListening.setRemoteWakeupInterval(msg, LPL_DEF_REMOTE_WAKEUP);		  	    	    
	    call MsgQueue.enqueue(*msg);
	    if( call MsgQueue.size() >= call MsgQueue.maxSize() ){
	    	atomic queueFull = TRUE;
	    }
	    send();
		return msg;
	}

	command void Packet.clear(message_t *msg){
		call SubPacket.clear(msg);
	}	

	command uint8_t Packet.payloadLength(message_t* msg){
		return call SubPacket.payloadLength(msg) - sizeof(opp_header_t);
	}
	
	command void Packet.setPayloadLength(message_t* msg, uint8_t len){
		call SubPacket.setPayloadLength(msg, len + sizeof(opp_header_t));
	}
	  
	command uint8_t Packet.maxPayloadLength(){
		return call SubPacket.maxPayloadLength() - sizeof(opp_header_t);
	}
	    
	command void* Packet.getPayload(message_t* msg, uint8_t len){
		uint8_t* payload = call SubPacket.getPayload(msg, len + sizeof(opp_header_t));
    	if (payload != NULL) {
      		payload += sizeof(opp_header_t);
    	}
    	return payload;
	}
	
	command error_t Control.start(){
		return call SubControl.start();
	}

	command error_t Control.stop(){
		return call SubControl.stop();
	}

	event void SubControl.startDone(error_t error) {
//	    call LowPowerListening.setLocalWakeupInterval(OPP_WAKEUP_INTERVAL);	
		signal Control.startDone(error);
  	}
    
  	event void SubControl.stopDone(error_t error) {
		signal Control.stopDone(error);
  	}
  	
//	uint8_t getMyEtx(){
//		return TOS_NODE_ID;
//	}
	
//	uint8_t getExpectedNextHopEtx(){
//		return TOS_NODE_ID -1;
//	}
	  	
	event void TxTimer.fired(){
		send();
	}  	
	
	task void send_task(){
		send();
	}
	 
  	void send(){
  		if( currentMsgPtr != NULL ){return;}
  		if( call TxTimer.isRunning() ){return;} //do not send other stuff when tx timer is runnning  		  		
  		if( !call MsgQueue.empty() ){ 
  			uint32_t txTime;
  			int hold;
  			bool ret;
  			currentMsg = call MsgQueue.head();
  			ret = call TxTime.get(&currentMsg, &txTime, &hold);
 			if( !ret || (hold == 0 && call TxTimer.getNow() >= txTime )){
 				//either not found or time expired: ok to transmit
	  			currentMsg = call MsgQueue.dequeue();
	  			currentMsgPtr = &currentMsg;
  				atomic queueFull = FALSE;
  				dummyMsgPtr = NULL; //any possible dummy msg that is scheduled it not required anymore, now
  			} else if( hold == 1 && call TxTimer.getNow() >= txTime ){
  				call MsgQueue.dequeue();
  				post send_task();
  				return;  			
  			} else {
  				//start timer to try again
				call TxTimer.startOneShot(txTime - call TxTimer.getNow() );
				return;  				
  			} 
  		} else if( appMsgPtr != NULL ){
  			currentMsgPtr = appMsgPtr;
  			dummyMsgPtr = NULL; //any possible dummy msg that is scheduled it not required anymore, now
  		} else if( dummyMsgPtr != NULL ) {
  			currentMsgPtr = dummyMsgPtr;  		
  		} else {
  			return;
  		}
		//TODO error handling
		txStartTime = call Timer.getNow();
		txCount = 0;
		if( call NbTable.getMyEdc() >= OPP_INVALID_EDC + 1 ){
			call OppPacket.setPull(currentMsgPtr, TRUE );
		}
		{
			bool ret = call SubSend.send( setAddr(call NbTable.getNextHopEdc(), call NbTable.getMyEdc()) , currentMsgPtr, call SubPacket.payloadLength(currentMsgPtr));
			if( ret != SUCCESS ){
				post send_task();
			}
		}
  		return;
  	}
 	
 	
 	uint8_t getEtx(am_addr_t addr){
 		return (uint8_t)(addr >> 8);
 	}
 	
	uint8_t getSourceEtx(am_addr_t addr){
		return (uint8_t)addr;
	}
	
	uint16_t setAddr(uint8_t etx, uint8_t ownEtx){
		return (etx << 8) | ownEtx;
	}
 	
 	void logSent(message_t* msg){
		call OppDebug.logEventMsg(NET_C_FE_SENT_MSG, 
					call OppPacket.getSeqNum(msg), 
					call OppPacket.getSource(msg), 
                    call AMPacket.destination(msg));
  	}

 	void logSentFail(message_t* msg){
		call OppDebug.logEventMsg(NET_C_FE_SENDDONE_WAITACK, 
					call OppPacket.getSeqNum(msg), 
					call OppPacket.getSource(msg), 
                    call AMPacket.destination(msg));
  	}

 	void logReceive(message_t* msg){
    	call OppDebug.logEventMsg(NET_C_FE_RCV_MSG,
					 call OppPacket.getSeqNum(msg), 
					 call OppPacket.getSource(msg), 
				     call AMPacket.source(msg));
 	}

 	void logLLDupReceive(message_t* msg){
 		call OppDebug.logEventMsg(NET_LL_DUPLICATE, 
					 //maybe we should log dsn here? 
					 call OppPacket.getSeqNum(msg),
					 call OppPacket.getSource(msg), 
				     call AMPacket.source(msg));
 	}

 	void logMediumBusy(message_t* msg){
 		call OppDebug.logEventMsg(NET_C_FE_SENDDONE_FAIL, 
					 call OppPacket.getSeqNum(msg),
					 call OppPacket.getSource(msg), 
				     call AMPacket.destination(msg));
 	}

 	void logAppSent(message_t* msg){
 		call OppDebug.logEventMsg(NET_APP_SENT, 
					 call OppPacket.getSeqNum(msg),
					 call OppPacket.getSource(msg), 
				     0);
 	}

 	task void logQueueFull_task(){
 		call OppDebug.logEvent(NET_C_FE_MSG_POOL_EMPTY);
 	}

	event message_t* SubDupReceive.receive(message_t *msg, void *payload, uint8_t len){
		logLLDupReceive(msg);
		return msg;
	}
	
	default command error_t OppDebug.logEventMsg(uint8_t type, uint16_t msg, am_addr_t origin, am_addr_t node) {
    	return SUCCESS;
    }
  
    default command error_t OppDebug.logEvent(bool) {
    	return SUCCESS;
    }
	
} 
