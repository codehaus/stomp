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

	public class STOMPSubscription {
		public var destinationType:String;
		public var destinationName:String;
		public var ackMode:String;
		public var selector:String;
		public var subscribed:Boolean=false;
		
		public function STOMPSubscription( _destinationName:String , _ackMode:String = "auto" , _selector:String = null ) {
			destinationName = _destinationName;
			ackMode = _ackMode;
			selector = _selector;
		}
		
		public function getSubCommand():String {
			return "SUBSCRIBE\ndestination: "+destinationName+"\nack: "+ackMode+"\n\n\u0000";
		}
	}
}