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
 
#include "CC2420.h"
#include "opp.h"

module UniqueReceiveP @safe() {
  provides {
    interface Receive;
    interface Receive as DuplicateReceive;
    interface Init;
    interface Unique;
    interface AsyncUnique;
    interface TxTime;
  }
  
  uses {
    interface Receive as SubReceive;
    interface CC2420PacketBody;
    interface Leds;
    interface LocalTime<TMilli>;
    interface Random;
  }
}

implementation {
  
  struct {
	uint32_t txTime;
    uint16_t source;
    uint8_t dsn;
    uint8_t hold:1, count:7;
  } receivedMessages[RECEIVE_HISTORY_SIZE];
  
  uint8_t writeIndex = 0;
  uint8_t lastSeen = 0;
  
  /** History element containing info on a source previously received from */
  uint8_t recycleSourceElement;
    
  enum {
    INVALID_ELEMENT = 0xFF,
  };
  
  /***************** Init Commands *****************/
  command error_t Init.init() {
    int i;
    for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
      receivedMessages[i].source = (am_addr_t) 0xFFFF;
      receivedMessages[i].dsn = 0;
      receivedMessages[i].count = 0;
      receivedMessages[i].txTime = 0;
      receivedMessages[i].hold = 0;
    }
    return SUCCESS;
  }
  
  /***************** Prototypes Commands ***************/
  int hasSeen(uint16_t msgSource, uint8_t msgDsn);
  void insert(uint16_t msgSource, uint8_t msgDsn, uint8_t count, uint32_t txTime, int hold);
//  uint16_t getSourceKey(message_t *msg);
  
  /***************** SubReceive Events *****************/
  event message_t *SubReceive.receive(message_t* msg, void* payload, uint8_t len) {

    uint16_t msgSource = (call CC2420PacketBody.getHeader(msg))->src;
    uint8_t msgDsn = (call CC2420PacketBody.getHeader(msg))->dsn;
	int element = hasSeen(msgSource, msgDsn);
	
	if( element != INVALID_ELEMENT ){
		uint8_t count;
		atomic{
			count = receivedMessages[element].count;
        	receivedMessages[element].count++;
        }
        if( count > 0 ){
      		return signal DuplicateReceive.receive(msg, payload, len);
        } 
	} else { 
      	insert(msgSource, msgDsn, 1, call LocalTime.get() + OPP_TX_WAIT, 0);
    }
    return signal Receive.receive(msg, payload, len);
  }
  
  /****************** Functions ****************/  
  /**
   * This function does two things:
   *  1. It loops through our entire receive history and detects if we've 
   *     seen this DSN before from the given source (duplicate packet)
   *  2. It detects if we've seen messages from this source before, so we know
   *     where to update our history if it turns out this is a new message.
   *
   * The global recycleSourceElement variable stores the location of the next insert
   * if we've received a packet from that source before.  Otherwise, it's up 
   * to the insert() function to decide who to kick out of our history.
   */
  int hasSeen(uint16_t msgSource, uint8_t msgDsn) {
    int i;
    int element;
    recycleSourceElement = INVALID_ELEMENT;

    atomic {
      for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
        element = (lastSeen + i) % RECEIVE_HISTORY_SIZE;
        if(receivedMessages[element].source == msgSource) {
          recycleSourceElement = element;
          if(receivedMessages[element].dsn == msgDsn) {
          	return element;
          }
        }
      }
    }
      
    return INVALID_ELEMENT;
  }
  
  /**
   * Insert the message into the history.  If we received a message from this
   * source before, insert it into the same location as last time and verify
   * that the "writeIndex" is not pointing to that location. Otherwise,
   * insert it into the "writeIndex" location.
   */
  void insert(uint16_t msgSource, uint8_t msgDsn, uint8_t count, uint32_t txTime, int hold) {
    uint8_t element = recycleSourceElement;
    bool increment = FALSE;
   
	  if(element == INVALID_ELEMENT || writeIndex == element) {
	    // Use the writeIndex element to insert this new message into
	    element = writeIndex;
	    increment = TRUE;
	  }
	
	  atomic{
	  	receivedMessages[element].source = msgSource;
	  	receivedMessages[element].dsn = msgDsn;
        receivedMessages[element].count = count;
        receivedMessages[element].txTime = txTime;
        receivedMessages[element].hold = hold;
	  }
	  if(increment) {
	    writeIndex++;
	    writeIndex %= RECEIVE_HISTORY_SIZE;
	  }
  }

  /**
   * Derive a key to to store the source address with.
   *
   * For long (EUI64) addresses, use the sum of the word in the
   * address as a key in the table to avoid manipulating the full
   * address.
   */
//  uint16_t getSourceKey(message_t *msg) {
//    cc2420_header_t *hdr = call CC2420PacketBody.getHeader(msg);
//    int s_mode = (hdr->fcf >> IEEE154_FCF_SRC_ADDR_MODE) & 0x3;
//    int d_mode = (hdr->fcf >> IEEE154_FCF_DEST_ADDR_MODE) & 0x3;
//    int s_offset = 2, s_len = 2;
//    uint16_t key = 0;
//    uint8_t *current = (uint8_t *)&hdr->dest;
//    int i;
//
//    if (s_mode == IEEE154_ADDR_EXT) {
//      s_len = 8;
//    }
//    if (d_mode == IEEE154_ADDR_EXT) {
//      s_offset = 8;
//    }
//
//    current += s_offset;
//    
//    for (i = 0; i < s_len; i++) {
//        key += current[i];
//    }
//    return key;
//  }
 
  /***************** Defaults ****************/
  default event message_t *DuplicateReceive.receive(message_t *msg, void *payload, uint8_t len) {
    return msg;
  }
  
  command bool Unique.checkAndAdd(uint16_t msgSource, uint8_t msgDsn){  
    if(hasSeen(msgSource, msgDsn) != INVALID_ELEMENT ) {
      return FALSE;
    } 
    insert(msgSource, msgDsn, 0, 0, 0);
    return TRUE;
   }

  async command bool AsyncUnique.check(uint16_t msgSource, uint8_t msgDsn){  
	int i;
    for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
    	if( receivedMessages[i].source == msgSource && receivedMessages[i].dsn == msgDsn ){
        	lastSeen = i;
          	receivedMessages[i].txTime = call LocalTime.get() + OPP_TX_WAIT;
		    if( TOS_NODE_ID == SINK_ID || receivedMessages[i].count == 0 || call Random.rand32() % (receivedMessages[i].count + 1) == 0 ){		    			         		
         		//sink always acks
         		receivedMessages[i].hold = 0;
 		    	return TRUE;
		    } else {
		    	//we are not accepting it, put on hold, we should not forward
         		receivedMessages[i].hold = 1;
 		   		return FALSE;
			}
   		}
	}
    return TRUE;
  }
  
  command bool TxTime.get(message_t* msg, uint32_t* txTime, int* hold){  
	int i;
    uint16_t msgSource =(call CC2420PacketBody.getHeader(msg))->src;
    uint8_t msgDsn = (call CC2420PacketBody.getHeader(msg))->dsn; 
	int element;
	
	atomic {
	    for(i = 0; i < RECEIVE_HISTORY_SIZE; i++) {
	        element = (lastSeen + i) % RECEIVE_HISTORY_SIZE;	    
	    	if(receivedMessages[element].source == msgSource && receivedMessages[element].dsn == msgDsn && receivedMessages[element].count > 0){ 
				*txTime = receivedMessages[element].txTime;
				*hold = receivedMessages[element].hold;
				
	            return TRUE;
	   		}
		}
	}
    return FALSE;
  }
}

