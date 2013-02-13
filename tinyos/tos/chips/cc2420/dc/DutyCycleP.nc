/*
 * Copyright (c) 2012-2013 Omprakash Gnawali, Olaf Landsiedel
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
 * @author Omprakash Gnawali
 */

module DutyCycleP{

	provides interface DutyCycle;	
	provides interface Init;
	
	uses interface LocalTime<T32khz> as LocalTime32khz;
	uses interface Timer<TMilli>;
	uses interface OppDebug;
	uses interface Leds;
} 

implementation {

	uint32_t lastUpdateTime;
	uint32_t totalTime;
	uint32_t upTimeData, upStartTime;
	uint32_t upTimeIdle;
	
	command error_t Init.init() {
   		lastUpdateTime = call LocalTime32khz.get();
   		totalTime = 0;
   		upTimeData = 0;
   		upTimeIdle = 0;
   		call Timer.startPeriodic(100000L);
    	return SUCCESS;
  	}

	void updateEnergyStat(uint32_t now) {
   		uint32_t t;
   		if( now < lastUpdateTime) {
     		t = (now + ((uint32_t)0xFFFFFFFF - lastUpdateTime));
   		} else {
     		t = (now - lastUpdateTime);
   		}
   		totalTime += t;
   		lastUpdateTime = now;
 	}
	
	command void DutyCycle.radioOn(){
	   	uint32_t now = call LocalTime32khz.get();
    	updateEnergyStat(now);
   		upStartTime = now;
	}
  
	command void DutyCycle.radioOff(bool action){
	   	uint32_t now = call LocalTime32khz.get();
	   	uint32_t d;
    	updateEnergyStat(now);
 		if (now < upStartTime) {
   			d = (now + ((uint32_t)0xFFFFFFFF - upStartTime));
 		} else {
   			d = (now - upStartTime);
 		}
 		if( action ){
			upTimeData += d;
 		} else {
	 		upTimeIdle += d;
 		}
	}
	
	event void Timer.fired(){
	   uint32_t dcycleData = (1000 * upTimeData) / totalTime;	   
	   uint32_t dcycleIdle = (1000 * upTimeIdle) / totalTime;	   
	   uint16_t time = (uint16_t)(call Timer.getNow() / 1024);
	   totalTime = 0;
	   upTimeData = 0;
	   upTimeIdle = 0;
	   call OppDebug.logEventDbg(NET_DC_REPORT, (uint16_t)dcycleData, time, (uint16_t)dcycleIdle);   
	}
	
}
