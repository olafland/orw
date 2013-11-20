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
 
#include <stdint.h>

#include "debug/ntDebug.h"

module NbTableP{
	provides interface Init;
	provides interface NbTable;
	provides interface DutyCycle;
	
	uses interface NtDebug;
	uses interface Leds;
	uses interface LocalTime<TMilli>;
}

implementation {
	
	nbTableEntry_t nbTable[OPP_NB_TABLE_SIZE];

	am_addr_t tempSrc;
	uint8_t tempEdc;
	
	uint8_t myEdc;
	uint8_t nextHopEdc;
	uint32_t avgDc;
	
//Debug	
//	uint8_t indexesInUse;
	uint8_t indexes;
	bool newDc;
	
	task void update_task();
	void update(am_addr_t addr, uint8_t edc);
	void computeEdc(int type);
	void computeEdcTime(int type, uint32_t txTime);	
	void updateAvgDc(uint32_t txTime);	
	void normalize();
	void age();
//	void fail();
	
#define OPP_FLOAT_FAC 1000L
#define OPP_EDC_FAC 10
#define OPP_P_STORE_FAC 100

	command error_t Init.init(){
		int i;
		if( TOS_NODE_ID != SINK_ID ){
			atomic myEdc = OPP_INVALID_EDC + 1;
			nextHopEdc = OPP_INVALID_EDC;
		} else {
			atomic myEdc = OPP_EDC_TX_PENALTY;
			nextHopEdc = 0;
		}
//		indexesInUse = 0;
		indexes = 0;
		memset(&nbTable, 0, sizeof(nbTable));
		avgDc = OPP_FLOAT_FAC / 4; //initial dc is one quarter
		newDc = FALSE;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
			nbTable[i].addr = OPP_NT_TABLE_INVALID_ENTRY;		
		}
		return SUCCESS;
	}

	async command void NbTable.update(uint16_t src, uint8_t edc, bool accept){
		if( TOS_NODE_ID != SINK_ID && edc < OPP_INVALID_EDC /*&& !accept*/){	
			tempSrc = src;
			tempEdc = edc;
			post update_task();
		}
	}
	
	command void NbTable.txEnd(int status, uint32_t txTime){	
		int i;
		if( TOS_NODE_ID != SINK_ID ){
			if( status == TX_SUCCESS ){
				if( newDc ){
					updateAvgDc(txTime);
					newDc = FALSE;
					computeEdcTime(NT_SUCCESS, txTime);
				} else {
					computeEdc(NT_SUCCESS);
				}
			} else if (status == TX_FAIL ){
				age();				
				//normalize();
				computeEdc(NT_FAIL);
			} else if (status == TX_HOLD ){
				computeEdc(NT_HOLD);
			}
			for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
				if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
					break;
				}
				nbTable[i].set = FALSE;
			}
		}
	}
	
	async command uint8_t NbTable.getMyEdc(){
		return myEdc;
	}
	
	command uint8_t NbTable.getNextHopEdc(){
		return nextHopEdc;
	}
	
#define OPP_MAX_TX_DC 5

	command uint8_t NbTable.getMaxTxDc(){
		uint32_t ret = ( avgDc * 2 / OPP_FLOAT_FAC) + 1;
		if( ret > OPP_MAX_TX_DC ) ret = OPP_MAX_TX_DC;
		return (uint8_t) ret;
	}	
		
	task void update_task(){
		am_addr_t src_local;
		uint16_t edc_local;
		atomic{
			src_local = tempSrc;
			edc_local = tempEdc;
		}
		update(src_local, edc_local);
		computeEdc(NT_UPDATE);
	}
		
	void addAtIndex(int i, am_addr_t addr, uint8_t edc, uint8_t count){
		if( nbTable[i].addr != OPP_NT_TABLE_INVALID_ENTRY /*&& i < OPP_NB_TABLE_SIZE - 1 */){		 
			//syntax: memmove(dst, src, n)
			memmove(&nbTable[i+1], &nbTable[i], (OPP_NB_TABLE_SIZE - i - 1) * sizeof(nbTableEntry_t));
		}
		nbTable[i].addr = addr;
		nbTable[i].count = count;
		nbTable[i].edc = edc;
		nbTable[i].set = TRUE;
		if( indexes < OPP_NB_TABLE_SIZE ){
			indexes++;
		}
	}

	void removeFromIndex(int i){
		//if( i < OPP_NB_TABLE_SIZE - 1 ){
		//syntax: memmove(dst, src, n)
		memmove(&nbTable[i], &nbTable[i+1], (OPP_NB_TABLE_SIZE - i - 1) * sizeof(nbTableEntry_t));
		//}
		nbTable[OPP_NB_TABLE_SIZE-1].addr = OPP_NT_TABLE_INVALID_ENTRY;
		if( indexes > 0 ){
			indexes--;
		}
	}

	int findEdc(uint8_t edc){		
		int i;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
			if( nbTable[i].edc > edc || nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
				return i;
			}
		}
		return -1;				
	}
	
	int findAddr(am_addr_t addr){
		int i;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
			if( nbTable[i].addr == addr ){
				return i;
			} 
			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY){
				return -1;
			}
		}
		return -1;				
	}

	void normalize(){
		int i;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
				return;
			}
			if( nbTable[i].count == 0 ){
				removeFromIndex(i);
				i--;
			} else {
				nbTable[i].count = nbTable[i].count >> 1;
			}
		}		
	}

	void age(){
		int i;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++){
			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
				return;
			}
			if( nbTable[i].edc >= OPP_INVALID_EDC){
				return;
			}			
			if( nbTable[i].edc < OPP_INVALID_EDC - OPP_EDC_AGE_PENALTY){
				nbTable[i].edc += OPP_EDC_AGE_PENALTY;
			} else {
				nbTable[i].edc = OPP_INVALID_EDC;
			}			
		}		
	}


/*#define OPP_FAIL_PENALTY 2

	void fail(){
		int i;
		int indexesInUseLocal = indexesInUse;
		for( i = 0; i < indexesInUseLocal; i++){
			nbTable[i].count = nbTable[i].count >> OPP_FAIL_PENALTY;
			if( nbTable[i].count == 0 ){
				removeFromIndex(i);
				i--;
				indexesInUseLocal--;
			}			
		}		
	}*/


#define OPP_NB_UPDATE_WEIGHT 1
#define OPP_NB_NORM_TH 32

	void update(am_addr_t addr, uint8_t edc){
		int i = findAddr(addr);
		//does addr exist		
		if( i != -1 ){
			//does it have a new EDC
			if( nbTable[i].edc != edc  ){
				//yes: remove, add, update
				uint8_t count = nbTable[i].count;
				if( !nbTable[i].set ){
					count += OPP_NB_UPDATE_WEIGHT;
				}
				removeFromIndex(i);
				addAtIndex(findEdc(edc), addr, edc, count);
				if( count >= OPP_NB_NORM_TH ){
					normalize();
				}					
			} else {
				if( !nbTable[i].set ){
					//no: just update count
					nbTable[i].count += OPP_NB_UPDATE_WEIGHT;
					nbTable[i].set = TRUE;
					if( nbTable[i].count >= OPP_NB_NORM_TH ){
						normalize();
					}
				}
			}
		} else {
			//find edc index and add
			i = findEdc(edc);
			if( i != -1 ){
				addAtIndex(i, addr, edc, OPP_NB_UPDATE_WEIGHT);				
			}
		}
	}

/*#define UNSTABLE_THRESHOLD_1 10
#define UNSTABLE_THRESHOLD_2 100

	int getThreshold(){
		int entries;
		int count = 0;
		for( entries = 0; entries < OPP_NB_TABLE_SIZE; entries++){
			if( nbTable[entries].addr == OPP_NT_TABLE_INVALID_ENTRY ){
				break;
			}
			count += nbTable[entries].count;
		}
		if( count < UNSTABLE_THRESHOLD_1 ){
			return 0;
		}
		if( count < UNSTABLE_THRESHOLD_2 ){
			return count / ( entries * ( 4 - ( ( entries - UNSTABLE_THRESHOLD_1 ) * 2 / (UNSTABLE_THRESHOLD_2 - UNSTABLE_THRESHOLD_1) )));			
		}
		return count / ( entries * 2 );
	}*/
	
#define OPP_AVG_WEIGHT (OPP_FLOAT_FAC / 5) // = 0.2 * OPP_FLOAT_FAC
	
	void updateAvgDc(uint32_t txTime){
		//avgDC = 0.2 * t + 0.8 * avgDc
		avgDc = (txTime * OPP_AVG_WEIGHT) / LPL_DEF_REMOTE_WAKEUP +
				(avgDc * (OPP_FLOAT_FAC - OPP_AVG_WEIGHT ) ) / OPP_FLOAT_FAC;
		if( avgDc == 0 ) avgDc = OPP_FLOAT_FAC;
	}
	
	uint32_t getTotalCount(){
		int i;
		uint32_t totalCount = 0;
		for( i = 0; i < OPP_NB_TABLE_SIZE; i++ ){
			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
				break;
			}
			if( nbTable[i].edc <= nextHopEdc ){
				totalCount += (uint32_t)nbTable[i].count;
			}
		}
		return totalCount;	
	} 
	
	//get p * OPP_FLOAT_FAC
	uint32_t computeP(uint32_t count, uint32_t totalCount){
		uint32_t p = 1; //Let's take 0.1% and not 0%, everybody who is on our table has as change of tx success
		//count / ( totalCount * dcf)		
		if( count != 0) {
			p = (OPP_FLOAT_FAC * OPP_FLOAT_FAC * count) / (avgDc * totalCount);
		} 
		return p;
	}
	
	uint8_t getP8(uint32_t p){
		p = (p * OPP_P_STORE_FAC) / OPP_FLOAT_FAC;
		if( p > UINT8_MAX ){
			p = UINT8_MAX;
		}
		return p;
	}

//	computeP(uint8_t* p){
//		int i;
//		uint32_t totalCount = 0;
//		for( i = 0; i < OPP_NB_TABLE_SIZE; i++ ){
//			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
//				break;
//			}
//			if( nbTable[i].edc <= nextHopEdc ){
//				totalCount += (uint32_t)nbTable[i].count;
//			}
//		}		
//		for( i = 0; i < OPP_NB_TABLE_SIZE; i++ ){
//			uint32_t pTemp;
//			if( nbTable[i].addr == OPP_NT_TABLE_INVALID_ENTRY ){
//				break;
//			}
//			//count / ( totalCount * dcf)		
//			//TODO: check use 2 dcf...
//			if( nbTable[i].count != 0) {
//				pTemp = (OPP_AVG_PSEUDO_FLOAT_FAC * OPP_PSEUDO_FLOAT_FAC * (uint32_t)nbTable[i].count) / (avgDc * totalCount * 2);
//			} else {
//				pTemp = 1; // Let's take 1% and not 0%, everybody who is on our table has as change of tx success
//			}
//			if( pTemp > 0xFF) pTemp = 0xFF;
//			p[i] = pTemp;
//		}		
//	}	

	void computeEdc(int type){
		computeEdcTime(type, UINT32_MAX);
	}

	void computeEdcTime(int type, uint32_t txTime){
		//just to be sure
		if( TOS_NODE_ID != SINK_ID ){
			int n;
			int indexesInUse = 0;
			uint32_t oldEdc = UINT32_MAX;
			uint16_t oldNextHopEdc = OPP_INVALID_EDC;
			uint32_t sumEdcTimesP = 0;
			uint32_t sumP = 0;
			uint32_t totalCount = getTotalCount();
			
			uint8_t p[OPP_NB_TABLE_SIZE] = {0}; //logging only
			
			for( n = 0; n < OPP_NB_TABLE_SIZE; n++ ){
				uint32_t edc;
				uint32_t pTemp;
				if( nbTable[n].addr == OPP_NT_TABLE_INVALID_ENTRY ){
					break;
				}				
				if( nbTable[n].edc >= OPP_INVALID_EDC){
					break;
				}				
				pTemp = computeP(nbTable[n].count, totalCount);								
				sumEdcTimesP += (uint32_t)nbTable[n].edc * pTemp;
				sumP += pTemp;
				p[n] = getP8(pTemp); //logging only
				if( sumP == 0 ){
					edc = (OPP_INVALID_EDC + 1) * OPP_FLOAT_FAC;
				} else {
					edc = ((OPP_FLOAT_FAC * OPP_EDC_FAC + sumEdcTimesP ) * OPP_FLOAT_FAC) / sumP;
				}		
				if( edc <= oldEdc && edc > (uint32_t)nbTable[n].edc * OPP_FLOAT_FAC){
					oldEdc = edc;
					oldNextHopEdc = nbTable[n].edc;
					indexesInUse = n + 1; //logging only?
				}
			}
			if( indexesInUse > 0 ){				
				oldEdc = (oldEdc / OPP_FLOAT_FAC) + OPP_EDC_TX_PENALTY;
//				oldNextHopEdc += OPP_EDC_TX_THRES;				
			} else {
				oldEdc = (OPP_INVALID_EDC + 1);
			}						
			if( oldEdc > OPP_INVALID_EDC + 1) oldEdc = OPP_INVALID_EDC + 1;
			if( oldNextHopEdc > OPP_INVALID_EDC ) oldNextHopEdc = OPP_INVALID_EDC;
			if( oldNextHopEdc > oldEdc ) oldNextHopEdc = oldEdc - 1;
			atomic myEdc = (uint8_t)oldEdc;
			nextHopEdc = (uint8_t)oldNextHopEdc;
			call NtDebug.dumpTable(&nbTable[0], &p[0], type, oldEdc, oldNextHopEdc, indexesInUse, indexes, avgDc, txTime, call LocalTime.get() );
		}
	}	
	
	command void DutyCycle.radioOn(){
	}
  
	command void DutyCycle.radioOff(bool action){
		newDc = TRUE;		
	}
	
  	default command error_t NtDebug.dumpTable(nbTableEntry_t* nbTable__, uint8_t* p__, uint8_t type__, uint8_t edc__, uint8_t nextHopEdc__, uint8_t indexesInUse__, uint8_t indexes__, uint32_t avgDc__, uint32_t txTime__, uint32_t timestamp__){
    	return SUCCESS;
    }
}
