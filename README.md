ORW
===

####Opportunistic Routing for Wireless Sensor Networks

The source code for our paper "Low Power, Low Delay: Opportunistic Routing meets Duty Cycling" published at IPSN 2012.

####Questions:
In case of any questions, contact Olaf Landsiedel olafl AT chalmers.se

####Compilation:
ORW requires a working TinyOS installation, with the TinyOS paths, etc., set as enviroment variables. 
The code in this repository only contains the files we added/modified compared to the default TinyOS implementation. 
We used TinyOS 2.1.1. As the TinyOS radio stack is quite stable, older and newer versions of TinyOS should be fine, too.
Make sure that your TinyOS paths and environments variables are set and download the ORW code into any directory (but do not copy it into the TinyOS directory, leave these two seperate). 
Compile with "make telosb oppxmac" in the TestNetworkLpl folder of ORW (in apps).

Update: March 2014: we did a minor change to CC24020.h. Now things should also be fine with the current version 2.1.2.

Update: September 2014: The recent changes in git head of TinyOS (new platform files etc.) require some extra fixes for which I did not yet have time to take care off. 
For TinyOS 2.1.2 everything seems fine, we just get some new warning regardings the naming of the platform files.

####ROM/RAM:
Without debugging/logging, ORW consumes about 7kB ROM and 1kB RAM in total (TinyOS base, ORW, sample application).
Overall, this is about 60% of the total that CTP requires.
By default, just as in CTP, we have debugging/logging enabled to that you can trace how packets travel through the network and how the routing table is updated. 
To disable debugging and logging and achieve the low RAM and ROM footprint, compile with NO_OPP_DEBUG set. 

####Porting:
ORW was tested on Telosb. 
However, it only depends on the CC2420 radio, as the current implementation hooks into its device driver to make the forwarding decision. 
Thus, using other CC2420 based platforms such as MicaZ should be ok. 
Based on user feedback (thanks to Faisal Aslam) it seems that ORW runs well on MicaZ, once you disbale logging (see above) or reduce the amount of data logged.
For other radios we expect a minor porting effort: 
The code that we added to the CC2420 driver is quite simple and we kept the main logic for the fowarding decision in a separate module.
