﻿/**
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
	
	import flash.events.Event;

	public class STOMPEvent extends Event {
		
		static public const SubscribedEvent:String = "SubscribedEvent";
		
		public var eventSummary:String;
		public var timeStamp:String;
		
		public var originalEventText:String;
		public var channel:String;
		
		public var eventEnv:Object;
		
		public function STOMPEvent( eventType:String , _eventEnv:Object ) {
			trace("Creating STOMP event");
			super(eventType,true,false);
			eventEnv = _eventEnv;
		}
		
		public override function clone():Event {
            return new STOMPEvent(type, eventEnv);
        }
		
		public function dumpEventEnv():void {
			if (eventEnv==null) {
				trace("Event Env was null");
				return;
			}
			for (var key:String in eventEnv) {
    			trace(key + ": " + eventEnv[key]);
			}
		}
	}
}