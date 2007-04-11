/**
 *
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
 
 /*
 	Version 0.1 : R Jewson (rjewson at gmail dot com).  First release, only for reciept of messages.
 */

package org.codehaus.stomp {
	
	import org.codehaus.stomp.STOMPEvent;
	import org.codehaus.stomp.STOMPSubscription;
	
	import flash.net.XMLSocket;
	
	import flash.events.Event;
	import flash.events.DataEvent;
	import flash.events.IOErrorEvent ;
	import flash.events.EventDispatcher;
    import flash.events.TimerEvent;
    import flash.utils.Timer;
	import flash.Date;
	import flash.display.*;
	
	public class STOMPClient extends Sprite {
  
  		static public const SHORT_INT:int = 1000;
		static public const MEDIUM_INT:int = 5000;
		static public const LONG_INT:int = 10000;
  
    	private var socket:XMLSocket = new XMLSocket(  );
 		
		private var server:String;
		private var port:String;
		
		public var autoReconnect:Boolean = true;
		
  		private var socketConnected:Boolean   = false;
		private var protocolPending:Boolean   = false;
		private var protocolConnected:Boolean = false;
		private var expectDisconnect:Boolean  = false;
		
		public var sessionID:String;
		public var setInterval:int = 0;
		private var subscriptions:Array = new Array();
		
		private var timer:Timer; 
		private var lightTimer:Timer;
		private var connectTimer:Timer;
		
		private var light_off:Shape;
		private var light_red:Shape;
		private var light_green:Shape;
		private var light_orange:Shape;
		
		private var linkLight:Shape;
		private var dataLight:Shape;
		
		public var connectTime:Date = null;
		public var disconnectTime:Date = null;
		public var connectAttempts:int = 0;

		public var errorMessages:Array = new Array();
		
  		public function STOMPClient(  ) {
			socket.addEventListener( Event.CONNECT, onConnect );
	  		socket.addEventListener( Event.CLOSE, onClose );
      		socket.addEventListener( DataEvent.DATA, onData );
			socket.addEventListener( IOErrorEvent.IO_ERROR, onError );
			
			light_red = CodedAssets.drawLight(0xFF3333);
			light_red.x=0;light_red.y=0;addChild(light_red);
			light_green = CodedAssets.drawLight(0x00FF00);
			light_green.x=0;light_green.y=0;light_green.visible=false;addChild(light_green);
			light_off = CodedAssets.drawLight(0x000000);
			light_off.x=0;light_off.y=4;addChild(light_off);
			light_orange = CodedAssets.drawLight(0xFF9900);
			light_orange.x=0;light_orange.y=4;light_orange.visible=false;addChild(light_orange);
			
			lightTimer = new Timer(300,1);
           	lightTimer.addEventListener("timer", onFlicker);
		}
	
		public function setTimer( interval:int ):void {
			if (setInterval==interval)
				return;
			if (timer!=null)
				timer.stop();
			timer = new Timer(interval);
			timer.addEventListener(TimerEvent.TIMER, onSubTick);
			timer.start();
			setInterval=interval;
		}
		
		public function onSubTick( event:TimerEvent ):void {
			processSubscriptionList();
		}
		public function doConnectTimer( event:TimerEvent ):void {
			doConnect();
		}
		public function onFlicker( event:TimerEvent ):void {
			light_orange.visible=false;
		}
	
		public function connect( _server:String, _port:String ):void {
			server = _server;
			port = _port
			doConnect();
		}
		
		private function doConnect():void {
			if (socketConnected==true)
				return;
			socket.connect( server, port );
			socketConnected = false;
			protocolConnected = false;
			protocolPending = true;
			expectDisconnect = false;
		}
	
		private function doDisconnect():void {
			expectDisconnect = true;
			socket.close();
		}
	
 	   	private function onConnect( event:Event ):void {
			if (connectTimer!=null) {
				connectTimer.stop();
			}
			socket.send( "CONNECT\n\n\u0000" );
			socketConnected = true;
    	}
	
		private function onClose( event:Event ):void {
			socketConnected = false;
			protocolConnected = false;
			protocolPending = false;
			light_green.visible=false;
			disconnectTime = new Date();
			for (var i:int = 0; i < subscriptions.length; i++) {
				subscriptions[i].subscribed = false;
			}
			if ((expectDisconnect==false)&&(autoReconnect==true)) {
				connectTimer = new Timer(MEDIUM_INT);
				connectTimer.addEventListener(TimerEvent.TIMER, doConnectTimer);
				connectTimer.start();
			}
		}

		private function onError( event:Event ):void {
			var now:Date = new Date();
			if (!socket.connected) {
				sockectConnected = false;
				protocolConnected = false;
				protocolPending = false;
				light_green.visible=false;
				disconnectTime = now;
			}
			errorMessages.push(now+" "+event.text);
		}
		
		public function subscribe( sub:STOMPSubscription ):void {
			subscriptions.push(sub);
			execSubscription(sub);
		}
		
		private function execSubscription( sub:STOMPSubscription ):Boolean {
			if (!protocolConnected) 
				return false;
			socket.send(sub.getSubCommand());
			return true;
		}

		public function processSubscriptionList():void {
			var allStarted:Boolean = true;
			for (var i:int = 0; i < subscriptions.length; i++) {
				if ( subscriptions[i].subscribed==false ) {
					if (execSubscription(subscriptions[i]))
						subscriptions[i].subscribed=true;
					else
						allStarted = false;
				}
			}
			if (allStarted)
				setTimer(LONG_INT);
			else
				setTimer(SHORT_INT);
		}
	
	    private function onData( event:DataEvent ):void {
			lightTimer.reset();
			lightTimer.start();
			light_orange.visible=true;
			
    		var a:Array = event.data.split("\n");
	  		if (a.length<1)
				return;
			/*
			//Dump the recieved data
			for (var i:int = 0; i < a.length; i++) {
	  			trace("line["+i+"]="+a[i]);
	  		}
			*/
			var startLine:int = 0;
			for (var i:int = 0; i < a.length; i++) {
				if (a[i].length>1) {
					startLine = i;
					break;
				}
	  		}
			
			if (a[startLine]=="CONNECTED") {
				protocolConnected = true;
				protocolPending = false;
				expectDisconnect==false;
				light_green.visible=true;
				connectTime = new Date();
				sessionID = a[startLine+1];
				setTimer(SHORT_INT);
				return;
			}
			switch (a[startLine]) {
				case "MESSAGE":
					var eventEnv:Object = new Object(  );
					var line:int = startLine+1;
					var endOfMessage:Boolean = false;
					var messageBody:String ="";
					while (a[line].length!=0) {
						var splitPos:int = a[line].indexOf(":");
						eventEnv[a[line].substring(0,splitPos)]=a[line].substring(splitPos+1,a[line].length);
						line++;
						if (line>a.length) {
							endOfMessage=true;
							break;
						}
					}
					if ((!endOfMessage)&&(++line<=a.length)) {
						while (a[line].length!=0) {
							messageBody += a[line]+"\n";
							line++;
							if (line>a.length) {
								endOfMessage=true;
								break;
							}
						}
					}
					eventEnv["messageBody"]=messageBody;
					dispatchEvent(new STOMPEvent(STOMPEvent.SubscribedEvent,eventEnv));
				break;
			}
		}
  	}
}
