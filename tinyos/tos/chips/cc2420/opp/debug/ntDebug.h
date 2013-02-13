#ifndef NT_DEBUG_H
#define NT_DEBUG_H

#include "../opp.h"

enum {
    NT_UPDATE = 0x1,
    NT_FAIL =  0x2,
    NT_SUCCESS = 0x3,
    NT_HOLD = 0x4
};

//expects nb table of size 30 => 6 dump msg, 1 action
//#define NT_DUMP_MSG_COUNT 6
//#define NT_DUMP_MSG_COUNT 0
#define NT_DUMP_MSG_COUNT 0

typedef nx_struct NtDebugMsg {
	nx_uint8_t type;
	nx_uint8_t edc;
	nx_uint8_t nextHopEdc;
	nx_uint8_t indexesInUse;
	nx_uint8_t indexes;
	nx_uint16_t seqNum;
	nx_uint32_t avgDc;
	nx_uint32_t txTime;
	nx_uint32_t timestamp;
} NtDebugMsg_t;


typedef nx_struct NtEntryDump {
	nx_uint16_t addr;
	nx_uint8_t count;
	nx_uint8_t edc;
	nx_uint8_t p;
} NtEntryDump_t;

#define NT_ENTRIES_PER_DUMP 5

typedef nx_struct NtDebugDumpMsg {
	nx_uint16_t seqNum;
	nx_uint8_t dumpNum;
	NtEntryDump_t ntEntry0;
	NtEntryDump_t ntEntry1;
	NtEntryDump_t ntEntry2;
	NtEntryDump_t ntEntry3;
	NtEntryDump_t ntEntry4;
} NtDebugDumpMsg_t;

#endif
