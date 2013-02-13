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

#ifndef OPP_H
#define OPP_H

#define MAX_TTL 20

#ifndef SINK_ID
#define SINK_ID 1
#endif

#define OPP_RECEIVE_HISTORY_SIZE 10

enum {
  AM_OPPDEBUGMSG = 22,
  AM_OPP_MSG = 23,
  AM_NTDEBUGMSG = 24,
  AM_NTDEBUGDUMPMSG = 25,
  AM_BEACONMSG = 26,
};

enum {
	TX_SUCCESS = 0x1,
  TX_FAIL =  0x2,
  TX_HOLD = 0x3
};


//seqNum 0: dummy msg
typedef nx_struct opp_header {
  nx_uint8_t ttl:7, pull:1;
  nx_uint8_t seqNum;
  nx_uint16_t src;
} opp_header_t;


#ifndef OPP_EDC_TX_PENALTY
#define OPP_EDC_TX_PENALTY 1
#endif

#ifndef OPP_NB_TABLE_SIZE
#define OPP_NB_TABLE_SIZE 30
#endif

#define OPP_NT_TABLE_INVALID_ENTRY 0xFFFF
#define OPP_INVALID_EDC 0xFE
//#define OPP_EDC_TX_THRES (OPP_EDC_TX_PENALTY/2)
//#define OPP_EDC_AGE_PENALTY (OPP_EDC_TX_PENALTY/4 + 1)
#define OPP_EDC_AGE_PENALTY 1
#define OPP_DUMMY_SEQ_NUM 0

#define OPP_RETX_OFFSET 300L
#define OPP_RETX_WINDOW 100L

#define OPP_RETX_DUMMY_OFFSET 100L
#define OPP_RETX_DUMMY_WINDOW 100L

#define OPP_TXFAIL_OFFSET 300L
#define OPP_TXFAIL_WINDOW 100L

#define OPP_TX_WAIT 15L

typedef struct nbTableEntry{
	uint16_t addr;
	uint8_t edc;
	uint8_t count:7, set:1;
} nbTableEntry_t;

#endif
