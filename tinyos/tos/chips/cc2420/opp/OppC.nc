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
 
#include "oppDebug.h"
#include "opp.h"

configuration OppC{
	provides interface Opp;
	provides interface Send;
	provides interface Receive;
	provides interface Packet;
	provides interface SplitControl;
}

implementation {
	components OppP;
	components LedsC;
	components ActiveMessageC;
	components MainC;
	components UniqueP;
	components new QueueC(message_t,10) as MsgQueue;
	components OppPacketP;
	components NbTableP;
	components LocalTimeMilliC;
  	components new TimerMilliC();
  	components new TimerMilliC() as TxTimer;
  	components RandomC;
  	components UniqueReceiveC;
#if defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
  components CC1000CsmaRadioC as LplRadio;
#elif defined(PLATFORM_MICAZ) || defined(PLATFORM_TELOSB) || defined(PLATFORM_SHIMMER) || defined(PLATFORM_SHIMMER2) || defined(PLATFORM_INTELMOTE2) || defined(PLATFORM_EPIC)
  components CC2420ActiveMessageC as LplRadio;
#elif defined(PLATFORM_IRIS) || defined(PLATFORM_MULLE)
  components RF230ActiveMessageC as LplRadio;
#elif defined(PLATFORM_EYESIFXV1) || defined(PLATFORM_EYESIFXV2)
  components LplC as LplRadio;
#else
#error "LPL testing not supported on this platform"
#endif
		
	Opp = OppP.Opp;
	Send = OppP.Send;
	Receive = OppP.Receive;
	Packet = OppP.Packet;
	SplitControl = OppP.Control;

	MainC -> OppP.Init;
	MainC -> UniqueP.Init;
	MainC -> NbTableP.Init;

	OppP.SubSend -> ActiveMessageC.AMSend[AM_OPP_MSG];
	OppP.SubReceive -> UniqueP.Receive; 
	OppP.SubPacket -> ActiveMessageC.Packet;
	OppP.Leds -> LedsC;
	OppP.MsgQueue -> MsgQueue;	
	OppP.PacketAcknowledgements -> ActiveMessageC;
	OppP.OppPacket -> OppPacketP;
	OppP.AMPacket -> ActiveMessageC;
	OppP.SubControl -> ActiveMessageC;
	OppP.LowPowerListening -> LplRadio;
	OppP.NbTable -> NbTableP;
	OppP.Timer -> TimerMilliC;
	OppP.TxTimer -> TxTimer;
	OppP.Random -> RandomC;
	
	OppPacketP.Packet -> ActiveMessageC.Packet;

	UniqueP.SubReceive -> ActiveMessageC.Receive[AM_OPP_MSG];
	UniqueP.OppPacket  -> OppPacketP;
	UniqueP.AMPacket -> ActiveMessageC;
	UniqueP.Leds -> LedsC;
	
	NbTableP.Leds -> LedsC;
	NbTableP.LocalTime -> LocalTimeMilliC;
	
	OppP.SubDupReceive -> UniqueReceiveC.DuplicateReceive;
	OppP.Unique -> UniqueReceiveC.Unique;
	OppP.TxTime -> UniqueReceiveC.TxTime;
		
#ifndef NO_OPP_DEBUG
	components new SerialAMSenderC(AM_OPPDEBUGMSG) as UARTSender;
  	components OppUARTDebugSenderP as DebugSender;
  	components new PoolC(message_t, 20) as DebugMessagePool;
  	components new QueueC(message_t*, 20) as DebugSendQueue;
  	components SerialActiveMessageC;
  	components CC2420ReceiveP;
  	components DefaultLplP;
  	DebugSender.Boot -> MainC;
  	DebugSender.UARTSend -> UARTSender;
  	DebugSender.MessagePool -> DebugMessagePool;
  	DebugSender.SendQueue -> DebugSendQueue;
  	DebugSender.SerialControl -> SerialActiveMessageC;
  	OppP.OppDebug -> DebugSender;
	UniqueP.OppDebug -> DebugSender;
	CC2420ReceiveP.OppDebug -> DebugSender;
//	DefaultLplP.OppDebug -> DebugSender;
//  	TestNetworkC.CollectionDebug -> DebugSender;

	components new SerialAMSenderC(AM_NTDEBUGMSG) as UARTSenderDebug;
	components new SerialAMSenderC(AM_NTDEBUGDUMPMSG) as UARTSenderDump;
  	components NtUARTDebugSenderP as NtDebugSender;
  	components new PoolC(message_t, 40) as NtDebugMessagePool;
  	components new QueueC(message_t*, 40) as NtDebugSendQueue;
  	NtDebugSender.Boot -> MainC;
  	NtDebugSender.UARTSendDebug -> UARTSenderDebug;
  	NtDebugSender.UARTSendDump -> UARTSenderDump;
  	NtDebugSender.MessagePool -> NtDebugMessagePool;
  	NtDebugSender.SendQueue -> NtDebugSendQueue;
  	NtDebugSender.SerialControl -> SerialActiveMessageC;
  	NtDebugSender.Packet -> SerialActiveMessageC;  	  	  	
	NtDebugSender.Leds -> LedsC;
	NbTableP.NtDebug -> NtDebugSender;
#endif	
} 
