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

module OppPacketP{
	provides interface OppPacket;
	
	uses interface Packet;
}

implementation {

	opp_header_t* getHeader(message_t* m) {
    	return (opp_header_t*)call Packet.getPayload(m, sizeof(opp_header_t));
  	}

  	command uint8_t OppPacket.getTtl(message_t* msg){
  		opp_header_t* header = getHeader(msg);
  		return header->ttl;
  	}
  
  	command void OppPacket.setTtl(message_t* msg, uint8_t ttl){
  		opp_header_t* header = getHeader(msg);
  		header->ttl = ttl;
  	}
  
  	command am_addr_t OppPacket.getSource(message_t* msg){
  		opp_header_t* header = getHeader(msg);
  		return header->src;
  	}
  
  	command void OppPacket.setSource(message_t* msg, am_addr_t src){
  		opp_header_t* header = getHeader(msg);
  		header->src = src;
  	}

  	command uint8_t OppPacket.getSeqNum(message_t* msg){
  		opp_header_t* header = getHeader(msg);
  		return header->seqNum;
  	}
  
  	command void OppPacket.setSeqNum(message_t* msg, uint8_t seqNum){
  		opp_header_t* header = getHeader(msg);
  		header->seqNum = seqNum;
  	}
  	
  	command bool OppPacket.isPull(message_t* msg){
  		opp_header_t* header = getHeader(msg);
  		return header->pull;
  	}
  	
  	command void OppPacket.setPull(message_t* msg, bool pull){
  		opp_header_t* header = getHeader(msg);
  		header->pull = pull;
  	}
  	
	command void OppPacket.init(message_t* msg, am_addr_t src, uint8_t seqNum, uint8_t ttl, bool pull){
  		opp_header_t* header = getHeader(msg);
  		header->src = src;
  		header->seqNum = seqNum;
  		header->ttl = ttl;
  		header->pull = pull;
	}
  	
}