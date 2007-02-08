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
package org.codehaus.stomp.jms;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.codehaus.stomp.ProtocolException;
import org.codehaus.stomp.Stomp;
import org.codehaus.stomp.StompFrame;

import javax.jms.Destination;
import javax.jms.JMSException;
import javax.jms.Message;
import javax.jms.MessageConsumer;
import javax.jms.MessageListener;
import javax.jms.Session;
import javax.jms.Topic;
import java.util.Map;

/**
 * Represents an individual Stomp subscription
 *
 * @version $Revision$
 */
public class StompSubscription implements MessageListener {
    public static final String AUTO_ACK = Stomp.Headers.Subscribe.AckModeValues.AUTO;
    public static final String CLIENT_ACK = Stomp.Headers.Subscribe.AckModeValues.CLIENT;
    private static final transient Log log = LogFactory.getLog(StompSubscription.class);
    private final StompSession session;
    private final String subscriptionId;
    private Destination destination;
    private MessageConsumer consumer;

    public StompSubscription(StompSession session, String subscriptionId, StompFrame frame) throws JMSException, ProtocolException {
        this.subscriptionId = subscriptionId;
        this.session = session;

        Map headers = frame.getHeaders();
        String selector = (String) headers.remove(Stomp.Headers.Subscribe.SELECTOR);
        String destinationName = (String) headers.get(Stomp.Headers.Subscribe.DESTINATION);
        destination = session.convertDestination(destinationName);
        Session jmsSession = session.getSession();
        boolean noLocal = false;

        if (destination instanceof Topic) {
            String value = (String) headers.get(Stomp.Headers.Subscribe.NO_LOCAL);
            if (value != null && "true".equalsIgnoreCase(value)) {
                noLocal = true;
            }

            String subscriberName = (String) headers.get(Stomp.Headers.Subscribe.DURABLE_SUBSCRIPTION_NAME);
            if (subscriberName != null) {
                consumer = jmsSession.createDurableSubscriber((Topic) destination, subscriberName, selector, noLocal);
            }
            else {
                consumer = jmsSession.createConsumer(destination, selector, noLocal);
            }
        }
        else {
            consumer = jmsSession.createConsumer(destination, selector);
        }
        consumer.setMessageListener(this);
    }

    public void close() throws JMSException {
        consumer.close();
    }

    public void onMessage(Message message) {
        try {
            int ackMode = session.getSession().getAcknowledgeMode();
            if (ackMode == Session.CLIENT_ACKNOWLEDGE) {
                synchronized (this) {
                    session.getProtocolConverter().addMessageToAck(message);
                }
            }
            session.sendToStomp(message, this);
        }
        catch (Exception e) {
            log.error("Failed to process message due to: " + e + ". Message: " + message, e);
        }
    }

    public String getSubscriptionId() {
        return subscriptionId;
    }

    public Destination getDestination() {
        return destination;
    }
}
