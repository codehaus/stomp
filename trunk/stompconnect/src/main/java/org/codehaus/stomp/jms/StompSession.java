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

import org.codehaus.stomp.ProtocolException;
import org.codehaus.stomp.Stomp;
import org.codehaus.stomp.StompFrame;

import javax.jms.*;
import java.io.IOException;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.Queue;

/**
 * Represents a logical session (a parallel unit of work) within a Stomp connection
 *
 * @version $Revision$
 */
public class StompSession {
    private final ProtocolConverter protocolConverter;
    private final Session session;
    private MessageProducer producer;
    private Map<String, Destination> temporaryDestinations = new HashMap<String, Destination>();

    public StompSession(ProtocolConverter protocolConverter, Session session) {
        this.protocolConverter = protocolConverter;
        this.session = session;
    }

    public ProtocolConverter getProtocolConverter() {
        return protocolConverter;
    }

    public Session getSession() {
        return session;
    }

    public MessageProducer getProducer() throws JMSException {
        if (producer == null) {
            producer = session.createProducer(null);
        }
        return producer;
    }

    public void close() throws JMSException {
        session.close();
    }

    public void sendToJms(StompFrame command) throws JMSException, ProtocolException {
        Map headers = command.getHeaders();
        String destinationName = (String) headers.remove(Stomp.Headers.Send.DESTINATION);
        Message message = convertFrame(command);

        Destination destination = convertDestination(destinationName);

        int deliveryMode = getDeliveryMode(headers);
        int priority = getPriority(headers);
        long timeToLive = getTimeToLive(headers);

        getProducer().send(destination, message, deliveryMode, priority, timeToLive);
    }

    public void sendToStomp(Message message, StompSubscription subscription) throws Exception {
        StompFrame frame = convertMessage(message);
        frame.getHeaders().put(Stomp.Headers.Message.SUBSCRIPTION, subscription.getSubscriptionId());
        protocolConverter.sendToStomp(frame);
    }

    public Destination convertDestination(String name) throws ProtocolException, JMSException {
        if (name == null) {
            throw new ProtocolException("No destination is specified!");
        }
        else if (name.startsWith("/queue/")) {
            String queueName = name.substring("/queue/".length(), name.length());
            return session.createQueue(queueName);
        }
        else if (name.startsWith("/topic/")) {
            String topicName = name.substring("/topic/".length(), name.length());
            return session.createTopic(topicName);
        }
        else if (name.startsWith("/temp-queue/")) {
            String tempName = name.substring("/temp-queue/".length(), name.length());
            return temporaryDestination(tempName, session.createTemporaryQueue());
        }
        else if (name.startsWith("/temp-topic/")) {
            String tempName = name.substring("/temp-topic/".length(), name.length());
            return temporaryDestination(tempName, session.createTemporaryTopic());
        }
        else {
            throw new ProtocolException("Illegal destination name: [" + name + "] -- StompConnect destinations " +
                    "must begine with one of: /queue/ /topic/ /temp-queue/ /temp-topic/");
        }
    }

    protected String convertDestination(Destination d) {
        if (d == null) {
            return null;
        }
        String physicalName = d.toString();

        StringBuffer buffer = new StringBuffer();
        if (d instanceof Queue) {
            if (d instanceof TemporaryQueue) {
                buffer.append("/temp-queue/");
            }
            else {
                buffer.append("/queue/");
            }
        }
        else {
            if (d instanceof TemporaryTopic) {
                buffer.append("/temp-topic/");
            }
            else {
                buffer.append("/topic/");
            }
        }
        buffer.append(physicalName);
        return buffer.toString();
    }

    protected synchronized Destination temporaryDestination(String tempName, Destination temporaryDestination) {
        Destination answer = temporaryDestinations.get(tempName);
        if (answer == null) {
            temporaryDestinations.put(tempName, temporaryDestination);
            answer = temporaryDestination;
        }
        return answer;
    }

    protected int getDeliveryMode(Map headers) throws JMSException {
        Object o = headers.remove(Stomp.Headers.Send.PERSISTENT);
        if (o != null) {
            return "true".equals(o) ? DeliveryMode.PERSISTENT : DeliveryMode.NON_PERSISTENT;
        }
        else {
            return getProducer().getDeliveryMode();
        }
    }

    protected int getPriority(Map headers) throws JMSException {
        Object o = headers.remove(Stomp.Headers.Send.PRIORITY);
        if (o != null) {
            return Integer.parseInt((String) o);
        }
        else {
            return getProducer().getPriority();
        }
    }

    protected long getTimeToLive(Map headers) throws JMSException {
        Object o = headers.remove(Stomp.Headers.Send.EXPIRATION_TIME);
        if (o != null) {
            return Long.parseLong((String) o);
        }
        else {
            return getProducer().getTimeToLive();
        }
    }

    protected void copyStandardHeadersFromMessageToFrame(Message message, StompFrame command) throws IOException, JMSException {
        final Map headers = command.getHeaders();
        headers.put(Stomp.Headers.Message.DESTINATION, convertDestination(message.getJMSDestination()));
        headers.put(Stomp.Headers.Message.MESSAGE_ID, message.getJMSMessageID());

        if (message.getJMSCorrelationID() != null) {
            headers.put(Stomp.Headers.Message.CORRELATION_ID, message.getJMSCorrelationID());
        }
        headers.put(Stomp.Headers.Message.EXPIRATION_TIME, "" + message.getJMSExpiration());

        if (message.getJMSRedelivered()) {
            headers.put(Stomp.Headers.Message.REDELIVERED, "true");
        }
        headers.put(Stomp.Headers.Message.PRORITY, "" + message.getJMSPriority());

        if (message.getJMSReplyTo() != null) {
            headers.put(Stomp.Headers.Message.REPLY_TO, convertDestination(message.getJMSReplyTo()));
        }
        headers.put(Stomp.Headers.Message.TIMESTAMP, "" + message.getJMSTimestamp());

        if (message.getJMSType() != null) {
            headers.put(Stomp.Headers.Message.TYPE, message.getJMSType());
        }

        // now lets add all the message headers
        Enumeration names = message.getPropertyNames();
        while (names.hasMoreElements()) {
            String name = (String) names.nextElement();
            Object value = message.getObjectProperty(name);
            headers.put(name, value);
        }
    }

    protected void copyStandardHeadersFromFrameToMessage(StompFrame command, Message msg) throws JMSException, ProtocolException {
        final Map headers = new HashMap(command.getHeaders());

        // the standard JMS headers
        msg.setJMSCorrelationID((String) headers.remove(Stomp.Headers.Send.CORRELATION_ID));

        Object o = headers.remove(Stomp.Headers.Send.TYPE);
        if (o != null) {
            msg.setJMSType((String) o);
        }

        o = headers.remove(Stomp.Headers.Send.REPLY_TO);
        if (o != null) {
            msg.setJMSReplyTo(convertDestination((String) o));
        }

        // now the general headers
        for (Iterator iter = headers.entrySet().iterator(); iter.hasNext();) {
            Map.Entry entry = (Map.Entry) iter.next();
            String name = (String) entry.getKey();
            Object value = entry.getValue();
            msg.setObjectProperty(name, value);
        }
    }

    protected Message convertFrame(StompFrame command) throws JMSException, ProtocolException {
        final Map headers = command.getHeaders();
        final Message msg;
        if (headers.containsKey(Stomp.Headers.CONTENT_LENGTH)) {
            headers.remove(Stomp.Headers.CONTENT_LENGTH);
            BytesMessage bm = session.createBytesMessage();
            bm.writeBytes(command.getContent());
            msg = bm;
        }
        else {
            String text;
            try {
                text = new String(command.getContent(), "UTF-8");
            }
            catch (Throwable e) {
                throw new ProtocolException("Text could not bet set: " + e, false, e);
            }
            msg = session.createTextMessage(text);
        }
        copyStandardHeadersFromFrameToMessage(command, msg);
        return msg;
    }

    protected StompFrame convertMessage(Message message) throws IOException, JMSException {
        StompFrame command = new StompFrame();
        command.setAction(Stomp.Responses.MESSAGE);
        Map headers = new HashMap(25);
        command.setHeaders(headers);

        copyStandardHeadersFromMessageToFrame(message, command);

        if (message instanceof TextMessage) {
            TextMessage msg = (TextMessage) message;
            command.setContent(msg.getText().getBytes("UTF-8"));
        }
        else if (message instanceof BytesMessage) {

            BytesMessage msg = (BytesMessage) message;
            byte[] data = new byte[(int) msg.getBodyLength()];
            msg.readBytes(data);

            headers.put(Stomp.Headers.CONTENT_LENGTH, "" + data.length);
            command.setContent(data);
        }
        return command;
    }
}
