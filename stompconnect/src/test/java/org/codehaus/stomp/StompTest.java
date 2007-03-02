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
package org.codehaus.stomp;

import junit.framework.Assert;
import junit.framework.TestCase;
import org.apache.activemq.ActiveMQConnectionFactory;
import org.apache.activemq.command.ActiveMQTextMessage;
import org.apache.activemq.transport.stomp.Stomp;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.codehaus.stomp.jms.StompConnect;

import javax.jms.BytesMessage;
import javax.jms.Connection;
import javax.jms.ConnectionFactory;
import javax.jms.JMSException;
import javax.jms.MessageConsumer;
import javax.jms.MessageProducer;
import javax.jms.Queue;
import javax.jms.Session;
import javax.jms.TextMessage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.SocketTimeoutException;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class StompTest extends TestCase {
    private static final transient Log log = LogFactory.getLog(StompTest.class);
    private int port = 61613;
    private StompConnect stompConnect;
    private Socket stompSocket;
    private ByteArrayOutputStream inputBuffer;
    private ConnectionFactory connectionFactory;
    private Connection connection;
    private Session session;
    private Queue queue;

    public void testConnect() throws Exception {

        String connect_frame = "CONNECT\n" + "login: brianm\n" + "passcode: wombats\n" + "request-id: 1\n" + "\n" + org.apache.activemq.transport.stomp.Stomp.NULL;
        sendFrame(connect_frame);

        String f = receiveFrame(10000);
        Assert.assertTrue(f.startsWith("CONNECTED"));
        Assert.assertTrue(f.indexOf("response-id:1") >= 0);
    }

    public void testSendMessage() throws Exception {

        MessageConsumer consumer = session.createConsumer(queue);

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SEND\n" +
                        "destination:/queue/" + getQueueName() + "\n\n" +
                        "Hello World" +
                        Stomp.NULL;

        sendFrame(frame);

        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertEquals("Hello World", message.getText());

        // Make sure that the timestamp is valid - should
        // be very close to the current time.
        long tnow = System.currentTimeMillis();
        long tmsg = message.getJMSTimestamp();
        Assert.assertTrue(Math.abs(tnow - tmsg) < 1000);
    }

    public void testJMSXGroupIdCanBeSet() throws Exception {

        MessageConsumer consumer = session.createConsumer(queue);

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SEND\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "JMSXGroupID: TEST\n\n" +
                        "Hello World" +
                        Stomp.NULL;

        sendFrame(frame);

        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertEquals("TEST", ((ActiveMQTextMessage) message).getGroupID());
    }

    public void testSendMessageWithCustomHeadersAndSelector() throws Exception {

        MessageConsumer consumer = session.createConsumer(queue, "foo = 'abc'");

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SEND\n" +
                        "foo:abc\n" +
                        "bar:123\n" +
                        "destination:/queue/" + getQueueName() + "\n\n" +
                        "Hello World" +
                        Stomp.NULL;

        sendFrame(frame);

        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertEquals("Hello World", message.getText());
        Assert.assertEquals("foo", "abc", message.getStringProperty("foo"));
        Assert.assertEquals("bar", "123", message.getStringProperty("bar"));
    }

    public void testSendMessageWithStandardHeaders() throws Exception {

        MessageConsumer consumer = session.createConsumer(queue);

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SEND\n" +
                        "correlation-id:c123\n" +
                        "priority:3\n" +
                        "type:t345\n" +
                        "JMSXGroupID:abc\n" +
                        "foo:abc\n" +
                        "bar:123\n" +
                        "destination:/queue/" + getQueueName() + "\n\n" +
                        "Hello World" +
                        Stomp.NULL;

        sendFrame(frame);

        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertEquals("Hello World", message.getText());
        Assert.assertEquals("JMSCorrelationID", "c123", message.getJMSCorrelationID());
        Assert.assertEquals("getJMSType", "t345", message.getJMSType());
        Assert.assertEquals("getJMSPriority", 3, message.getJMSPriority());
        Assert.assertEquals("foo", "abc", message.getStringProperty("foo"));
        Assert.assertEquals("bar", "123", message.getStringProperty("bar"));

        Assert.assertEquals("JMSXGroupID", "abc", message.getStringProperty("JMSXGroupID"));
        ActiveMQTextMessage amqMessage = (ActiveMQTextMessage) message;
        Assert.assertEquals("GroupID", "abc", amqMessage.getGroupID());
    }

    public void testSubscribeWithAutoAck() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        sendMessage(getName());

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
    }

    public void testSubscribeWithAutoAckAndBytesMessage() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        sendBytesMessage(new byte[]{1, 2, 3, 4, 5});

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        Pattern cl = Pattern.compile("Content-length:\\s*(\\d+)", Pattern.CASE_INSENSITIVE);
        Matcher cl_matcher = cl.matcher(frame);
        Assert.assertTrue(cl_matcher.find());
        Assert.assertEquals("5", cl_matcher.group(1));

        Assert.assertFalse(Pattern.compile("type:\\s*null", Pattern.CASE_INSENSITIVE).matcher(frame).find());

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
    }

    public void testSubscribeWithMessageSentWithProperties() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        MessageProducer producer = session.createProducer(queue);
        TextMessage message = session.createTextMessage("Hello World");
        message.setStringProperty("s", "value");
        message.setBooleanProperty("n", false);
        message.setByteProperty("byte", (byte) 9);
        message.setDoubleProperty("d", 2.0);
        message.setFloatProperty("f", (float) 6.0);
        message.setIntProperty("i", 10);
        message.setLongProperty("l", 121);
        message.setShortProperty("s", (short) 12);
        producer.send(message);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

//        System.out.println("out: "+frame);

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
    }

    public void testMessagesAreInOrder() throws Exception {
        int ctr = 10;
        String[] data = new String[ctr];

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        for (int i = 0; i < ctr; ++i) {
            data[i] = getName() + i;
            sendMessage(data[i]);
        }

        for (int i = 0; i < ctr; ++i) {
            frame = receiveFrame(1000);
            Assert.assertTrue("Message not in order", frame.indexOf(data[i]) >= 0);
        }

        // sleep a while before publishing another set of messages
        waitForFrameToTakeEffect();

        for (int i = 0; i < ctr; ++i) {
            data[i] = getName() + ":second:" + i;
            sendMessage(data[i]);
        }

        for (int i = 0; i < ctr; ++i) {
            frame = receiveFrame(1000);
            Assert.assertTrue("Message not in order", frame.indexOf(data[i]) >= 0);
        }

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
    }

    public void testSubscribeWithAutoAckAndSelector() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "selector: foo = 'zzz'\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        sendMessage("Ignored message", "foo", "1234");
        sendMessage("Real message", "foo", "zzz");

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));
        Assert.assertTrue("Should have received the real message but got: " + frame, frame.indexOf("Real message") > 0);

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
    }

    public void testSubscribeWithClientAck() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:client\n\n" +
                        Stomp.NULL;

        sendFrame(frame);
        sendMessage(getName());
        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        // message should be received since message was not acknowledged
        MessageConsumer consumer = session.createConsumer(queue);
        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertTrue(message.getJMSRedelivered());
    }

    public void testSubscribeWithClientAckThenConsumingAgainWithAutoAckWithNoDisconnectFrame() throws Exception {
        assertSubscribeWithClientAckThenConsumeWithAutoAck(false);
    }

    public void testSubscribeWithClientAckThenConsumingAgainWithAutoAckWithExplicitDisconnect() throws Exception {
        assertSubscribeWithClientAckThenConsumeWithAutoAck(true);
    }

    protected void assertSubscribeWithClientAckThenConsumeWithAutoAck(boolean sendDisconnect) throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:client\n\n" +
                        Stomp.NULL;

        sendFrame(frame);
        sendMessage(getName());

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        log.info("Reconnecting!");
        
        if (sendDisconnect) {
            frame =
                    "DISCONNECT\n" +
                            "\n\n" +
                            Stomp.NULL;
            sendFrame(frame);
            reconnect();
        }
        else {
            reconnect(1000);
        }


        // message should be received since message was not acknowledged
        frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n\n" +
                        Stomp.NULL;

        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        frame =
                "DISCONNECT\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        // now lets make sure we don't see the message again
        reconnect();

        frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n\n" +
                        Stomp.NULL;

        sendFrame(frame);
        sendMessage("shouldBeNextMessage");

        frame = receiveFrame(10000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));
        Assert.assertTrue(frame.contains("shouldBeNextMessage"));
    }

    public void testUnsubscribe() throws Exception {

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);
        frame = receiveFrame(100000);
        Assert.assertTrue(frame.startsWith("CONNECTED"));

        frame =
                "SUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "ack:auto\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        //send a message to our queue
        sendMessage("first message");

        //receive message from socket
        frame = receiveFrame(1000);
        Assert.assertTrue(frame.startsWith("MESSAGE"));

        //remove suscription
        frame =
                "UNSUBSCRIBE\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        waitForFrameToTakeEffect();

        //send a message to our queue
        sendMessage("second message");

        try {
            frame = receiveFrame(1000);
            log.info("Received frame: " + frame);
            Assert.fail("No message should have been received since subscription was removed");
        }
        catch (SocketTimeoutException e) {

        }
    }

    public void testTransactionCommit() throws Exception {
        MessageConsumer consumer = session.createConsumer(queue);

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        String f = receiveFrame(1000);
        Assert.assertTrue(f.startsWith("CONNECTED"));

        frame =
                "BEGIN\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "SEND\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        "Hello World" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "COMMIT\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        waitForFrameToTakeEffect();

        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull("Should have received a message", message);
    }

    public void testTransactionRollback() throws Exception {
        MessageConsumer consumer = session.createConsumer(queue);

        String frame =
                "CONNECT\n" +
                        "login: brianm\n" +
                        "passcode: wombats\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        String f = receiveFrame(1000);
        Assert.assertTrue(f.startsWith("CONNECTED"));

        frame =
                "BEGIN\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "SEND\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "transaction: tx1\n" +
                        "\n" +
                        "first message" +
                        Stomp.NULL;
        sendFrame(frame);

        //rollback first message
        frame =
                "ABORT\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "BEGIN\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "SEND\n" +
                        "destination:/queue/" + getQueueName() + "\n" +
                        "transaction: tx1\n" +
                        "\n" +
                        "second message" +
                        Stomp.NULL;
        sendFrame(frame);

        frame =
                "COMMIT\n" +
                        "transaction: tx1\n" +
                        "\n\n" +
                        Stomp.NULL;
        sendFrame(frame);

        // This test case is currently failing
        waitForFrameToTakeEffect();

        //only second msg should be received since first msg was rolled back
        TextMessage message = (TextMessage) consumer.receive(1000);
        Assert.assertNotNull(message);
        Assert.assertEquals("second message", message.getText().trim());
    }

    // Implementation methods
    //-------------------------------------------------------------------------
    protected void setUp() throws Exception {
        connectionFactory = createConnectionFactory();
        stompConnect = new StompConnect(connectionFactory);
        stompConnect.setUri("tcp://localhost:" + port);
        stompConnect.start();

        stompSocket = createSocket();
        inputBuffer = new ByteArrayOutputStream();

        connection = connectionFactory.createConnection();
        session = connection.createSession(false, Session.AUTO_ACKNOWLEDGE);
        queue = session.createQueue(getQueueName());
        connection.start();
    }

    protected void tearDown() throws Exception {
        connection.close();
        if (stompSocket != null) {
            stompSocket.close();
        }
        stompConnect.stop();
    }

    protected void reconnect() throws Exception {
        reconnect(0);
    }
    protected void reconnect(long sleep) throws Exception {
        stompSocket.close();

        if (sleep > 0) {
            Thread.sleep(sleep);
        }

        stompSocket = createSocket();
        inputBuffer = new ByteArrayOutputStream();
    }

    protected ConnectionFactory createConnectionFactory() {
        return new ActiveMQConnectionFactory("vm://localhost?broker.persistent=false&broker.useJmx=false");
    }

    protected Socket createSocket() throws IOException {
        return new Socket("127.0.0.1", port);
    }

    protected String getQueueName() {
        return getClass().getName() + "." + getName();
    }

    public void sendFrame(String data) throws Exception {
        byte[] bytes = data.getBytes("UTF-8");
        OutputStream outputStream = stompSocket.getOutputStream();
        for (int i = 0; i < bytes.length; i++) {
            outputStream.write(bytes[i]);
        }
        outputStream.flush();
    }

    public String receiveFrame(long timeOut) throws Exception {
        stompSocket.setSoTimeout((int) timeOut);
        InputStream is = stompSocket.getInputStream();
        int c = 0;
        for (; ;) {
            c = is.read();
            if (c < 0) {
                throw new IOException("socket closed.");
            }
            else if (c == 0) {
                c = is.read();
                Assert.assertEquals("Expecting stomp frame to terminate with \0\n", c, '\n');
                byte[] ba = inputBuffer.toByteArray();
                inputBuffer.reset();
                return new String(ba, "UTF-8");
            }
            else {
                inputBuffer.write(c);
            }
        }
    }

    public void sendMessage(String msg) throws Exception {
        sendMessage(msg, "foo", "xyz");
    }

    public void sendMessage(String msg, String propertyName, String propertyValue) throws JMSException {
        MessageProducer producer = session.createProducer(queue);
        TextMessage message = session.createTextMessage(msg);
        message.setStringProperty(propertyName, propertyValue);
        producer.send(message);
    }

    public void sendBytesMessage(byte[] msg) throws Exception {
        MessageProducer producer = session.createProducer(queue);
        BytesMessage message = session.createBytesMessage();
        message.writeBytes(msg);
        producer.send(message);
    }

    protected void waitForFrameToTakeEffect() throws InterruptedException {
        // bit of a dirty hack :)
        // another option would be to force some kind of receipt to be returned
        // from the frame
        Thread.sleep(2000);
    }
}
