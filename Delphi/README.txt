This delphi control implements a stomp client. In background it makes use of TClientSocket(under controls tab "internet" - ClientSocket). Because nonblocking TCP suited its original use better, so I have chosed this mode. 

The code for the control is in "source" directory. In "example" directory there is an straightforward example.

You may contact its author at pdvyuan@hotmail.com

Have fun!

Dingwen Yuan

v0.1 basic stomp client
v0.2 stomp client that support failover in round robin mode between multiple brokers.
		 to disable it, set "TestConnection" property to false before "open" operation.
