/**
 * TestNetworkC exercises the basic networking layers, collection and
 * dissemination. The application samples DemoSensorC at a basic rate
 * and sends packets up a collection tree. The rate is configurable
 * through dissemination. The default send rate is every 10s.
 *
 * See TEP118: Dissemination and TEP 119: Collection for details.
 * 
 * @author Philip Levis
 * @author Olaf Landsiedel (ORW changes) 
 * @version $Revision: 1.1 $ $Date: 2009-09-16 00:53:47 $
 */

#include <Timer.h>
#include "opp.h"
#include "TestNetworkLpl.h"

module TestNetworkLplC {
  uses interface Boot;
  uses interface SplitControl as RadioControl;
  uses interface Send;
  uses interface Leds;
  uses interface Timer<TMilli>;
  uses interface Random;
  uses interface Packet;
  uses interface Receive;
  uses interface ActiveMessageAddress;	  
#ifdef CHURN
  uses interface Timer<TMilli> as KillTimer;		 
#endif
}
implementation {

  message_t packet;
  bool sendBusy = FALSE;
  uint16_t counter;

  enum {
    SEND_INTERVAL = 60L*TEST_NETWORK_PACKET_RATE,
  };

  event void Boot.booted() {
#ifdef CHURN
	uint32_t interval = ((TOS_NODE_ID - 1) % 10) * 1024L * 60 * 15;
	if(interval > 0){
		call KillTimer.startOneShot( interval );
	} 
#endif 
    counter = 0;
    sendBusy = FALSE;
    call RadioControl.start();
  }
  
  event void RadioControl.startDone(error_t err) {
    if (err != SUCCESS) {
      call RadioControl.start();
    }
    else {
		call ActiveMessageAddress.setAddress(call ActiveMessageAddress.amGroup(), TOS_NODE_ID);
    	if( TOS_NODE_ID != SINK_ID ){
        	call Timer.startOneShot(call Random.rand32() % SEND_INTERVAL);
	      	//call Timer.startOneShot( 30*1024L*((TOS_NODE_ID % 4) + 1) );
	    }
    }
  }

  async event void ActiveMessageAddress.changed(){}

  event void RadioControl.stopDone(error_t err) {}
  
  void sendMessage() {
   	int i;
    test_lpl_msg_t* msg = (test_lpl_msg_t*)call Packet.getPayload(&packet, sizeof(test_lpl_msg_t));
  	if (msg == NULL) {
	  return;
   	}
	for( i = 0; i < sizeof(test_lpl_msg_t); i++ ){
      msg->data[i] = counter;
	}
	if (call Send.send(&packet, sizeof(test_lpl_msg_t)) == SUCCESS){
      sendBusy = TRUE;
	}
  }
 
  event void Timer.fired() {
    uint32_t nextInt;
    nextInt = call Random.rand32() % SEND_INTERVAL;
    nextInt += SEND_INTERVAL >> 1;
    call Timer.startOneShot(nextInt);
    if (!sendBusy) sendMessage();
    counter++;
  }

  event void Send.sendDone(message_t* m, error_t err) {
    sendBusy = FALSE;
  } 
  
  event message_t* Receive.receive(message_t* bufPtr, 
				   void* payload, uint8_t len){
    return bufPtr;
  }

#ifdef CHURN
	event void KillTimer.fired(){
		call RadioControl.stop();
		//call Leds.led2On();
	}	 
#endif   
}
