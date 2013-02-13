TOSMAKE_PATH=../../support/make/

COMPONENT=TestNetworkLplAppC

BUILD_EXTRA_DEPS = java/OppDebugMsg.class java/NtDebugMsg.class java/NtDebugDumpMsg.class
CLEAN_EXTRA = java/OppDebugMsg.java java/OppDebugMsg.class java/NtDebugMsg.java java/NtDebugMsg.class java/NtDebugDumpMsg.java java/NtDebugDumpMsg.class

DEFAULT_LOCAL_GROUP=0x23

CFLAGS+= -DLOW_POWER_LISTENING -DCC2420_NO_ADDRESS_RECOGNITION
CFLAGS+= -DDELAY_AFTER_RECEIVE=30
#CFLAGS+= -DNO_OPP_DEBUG

ifdef OL_CUSTOM_LPL
CFLAGS += -DLPL_DEF_LOCAL_WAKEUP=$(OL_CUSTOM_LPL)
CFLAGS += -DLPL_DEF_REMOTE_WAKEUP=$(OL_CUSTOM_LPL)
else
CFLAGS += -DLPL_DEF_LOCAL_WAKEUP=2048
CFLAGS += -DLPL_DEF_REMOTE_WAKEUP=2048
endif

ifdef OL_CUSTOM_PR
CFLAGS += -DTEST_NETWORK_PACKET_RATE=$(OL_CUSTOM_PR)
else
CFLAGS += -DTEST_NETWORK_PACKET_RATE=4096
endif

ifdef OL_CUSTOM_CH
CFLAGS += -DCC2420_DEF_CHANNEL=$(OL_CUSTOM_CH)
endif

ifdef OL_CUSTOM_W
CFLAGS += -DOPP_EDC_TX_PENALTY=$(OL_CUSTOM_W)
endif

ifdef OL_CUSTOM_TABLE_SIZE
CFLAGS += -DOPP_NB_TABLE_SIZE=$(OL_CUSTOM_TABLE_SIZE)
endif

ifdef OL_CUSTOM_ACK_WAIT
CFLAGS += -DOPP_ACK_WAIT=$(OL_CUSTOM_ACK_WAIT) -DDELAY_AFTER_RECEIVE=10
endif

ifdef OL_CHURN
CFLAGS += -DCHURN  
endif

ifdef OL_SINK
CFLAGS += -DSINK_ID=$(OL_SINK)
endif

ifdef OL_CUSTOM_PW
CFLAGS += -DCC2420_DEF_RFPOWER=$(OL_CUSTOM_PW)
endif

#CFLAGS += -DENABLE_SPI0_DMA  
#CFLAGS += -DCC2420_DEF_RFPOWER=2

java/OppDebugMsg.java: ../../tos/chips/cc2420/opp/debug/oppDebug.h
	mkdir -p java/
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=OppDebugMsg ../../tos/chips/cc2420/opp/debug/oppDebug.h OppDebugMsg -o $@

java/OppDebugMsg.class: java/OppDebugMsg.java
	javac -source 1.4 -target 1.4 java/OppDebugMsg.java

java/NtDebugMsg.java: ../../tos/chips/cc2420/opp/debug/ntDebug.h
	mkdir -p java/
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=NtDebugMsg ../../tos/chips/cc2420/opp/debug/ntDebug.h NtDebugMsg -o $@

java/NtDebugMsg.class: java/NtDebugMsg.java
	javac -source 1.4 -target 1.4 java/NtDebugMsg.java

java/NtDebugDumpMsg.java: ../../tos/chips/cc2420/opp/debug/ntDebug.h
	mkdir -p java/
	mig java -target=$(PLATFORM) $(CFLAGS) -java-classname=NtDebugDumpMsg ../../tos/chips/cc2420/opp/debug/ntDebug.h NtDebugDumpMsg -o $@

java/NtDebugDumpMsg.class: java/NtDebugDumpMsg.java
	javac -source 1.4 -target 1.4 java/NtDebugDumpMsg.java

include $(MAKERULES)
