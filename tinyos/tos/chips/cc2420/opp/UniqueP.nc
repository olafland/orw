/*
 * Copyright (c) 2005-2006 Rincon Research Corporation
 * Extensions for ORW: Copyright (c) 2012-2013 Olaf Landsiedel
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
 * - Neither the name of the Rincon Research Corporation nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE
 * RINCON RESEARCH OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE
 */
 
/** 
 * This layer keeps a history of the past RECEIVE_HISTORY_SIZE received messages
 * If the source address and dsn number of a newly received message matches
 * our recent history, we drop the message because we've already seen it.
 * @author David Moss
 * @author Olaf Landsiedel
 */
  
#include "opp.h"

module UniqueP{
  provides {
    interface Receive;
    interface Init;
  }
  
  uses {
    interface Receive as SubReceive;
    interface OppPacket;
    interface OppDebug;
    interface AMPacket;
    interface Leds;
  }
}

implementation {
  
  struct {
    uint16_t source;
    uint8_t seqNum;
  } receivedMessages[OPP_RECEIVE_HISTORY_SIZE];
  
  uint8_t writeIndex;
 
  void logDup(message_t* msg);
      
  /***************** Init Commands *****************/
  command error_t Init.init() {
    int i;
    for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
      receivedMessages[i].source = (am_addr_t) 0xFFFF;
      receivedMessages[i].seqNum = 0;
    }
    writeIndex = 0;
    return SUCCESS;
  }
  
  /***************** Prototypes Commands ***************/
  bool hasSeen(uint16_t source, uint8_t seqNum);
  void insert(uint16_t source, uint8_t seqNum);
  
  /***************** SubReceive Events *****************/
  event message_t *SubReceive.receive(message_t* msg, void* payload, uint8_t len) {

	opp_header_t* oppHeader;
	uint16_t source;
	uint8_t seqNum;

	if( len < sizeof(opp_header_t) ) {return msg;}
	
	oppHeader = (opp_header_t*) payload;
	source = oppHeader->src;
	seqNum = oppHeader->seqNum;

    if(!hasSeen(source, seqNum)) {
      insert(source, seqNum);
      return signal Receive.receive(msg, payload, len);
    }
    logDup(msg);
    return msg;
  }
  
  bool hasSeen(uint16_t source, uint8_t seqNum) {
    int i;
    if( seqNum == OPP_DUMMY_SEQ_NUM ){
    	return FALSE;
    }
	for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
    	if(receivedMessages[i].source == source && receivedMessages[i].seqNum == seqNum) {
			return TRUE;
    	}
  	}
    return FALSE;
  }
  
  void insert(uint16_t source, uint8_t seqNum) {   
	receivedMessages[writeIndex].source = source;
   	receivedMessages[writeIndex].seqNum = seqNum;
    writeIndex++;
    writeIndex %= RECEIVE_HISTORY_SIZE;
  }  
  
  void logDup(message_t* msg){
	call OppDebug.logEventMsg(NET_C_FE_DUPLICATE_CACHE, 
				call OppPacket.getSeqNum(msg), 
				call OppPacket.getSource(msg), 
                call AMPacket.source(msg));
  }
  
  	default command error_t OppDebug.logEventMsg(uint8_t type, uint16_t msg, am_addr_t origin, am_addr_t node) {
    	return SUCCESS;
    }
  
  
}

