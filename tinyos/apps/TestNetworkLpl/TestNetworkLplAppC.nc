/**
 * TestNetworkLplC exercises the basic networking layers, collection and
 * dissemination. The application samples DemoSensorC at a basic rate
 * and sends packets up a collection tree. The rate is configurable
 * through dissemination.
 *
 * See TEP118: Dissemination, TEP 119: Collection, and TEP 123: The
 * Collection Tree Protocol for details.
 * 
 * @author Philip Levis
 * @author Olaf Landsiedel (ORW changes) 
 * @version $Revision: 1.1 $ $Date: 2009-09-16 00:53:47 $
 */

configuration TestNetworkLplAppC {}
implementation {
  components TestNetworkLplC, MainC, LedsC, ActiveMessageC;
  components new TimerMilliC();
  components OppC;
  components RandomC;
  components ActiveMessageAddressC;

  TestNetworkLplC.Boot -> MainC;
  TestNetworkLplC.RadioControl -> OppC;
  TestNetworkLplC.Leds -> LedsC;
  TestNetworkLplC.Timer -> TimerMilliC;
  TestNetworkLplC.Send -> OppC.Send;
  TestNetworkLplC.Receive -> OppC.Receive;
  TestNetworkLplC.Packet -> OppC;  
  TestNetworkLplC.Random -> RandomC;  
  TestNetworkLplC.ActiveMessageAddress -> ActiveMessageAddressC;
  
#ifdef CHURN
#warning CHURN enabled
  components new TimerMilliC() as KillTimer;
  TestNetworkLplC.KillTimer -> KillTimer;
#endif 
}
