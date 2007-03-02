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
import org.codehaus.stomp.StompFrameError;
import org.codehaus.stomp.StompHandler;
import org.codehaus.stomp.util.IntrospectionSupport;

import javax.jms.Connection;
import javax.jms.ConnectionFactory;
import javax.jms.JMSException;
import javax.jms.Message;
import javax.jms.Session;
import java.io.ByteArrayOutputStream;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.Map;
import java.util.Collection;
import java.util.ArrayList;
import java.util.concurrent.ConcurrentHashMap;

/**
 * A protocol switch between JMS and Stomp
 *
 * @author <a href="http://people.apache.org/~jstrachan/">James Strachan</a>
 * @author <a href="http://hiramchirino.com">chirino</a>
 */
public class ProtocolConverter implements StompHandler {
    private static final transient Log log = LogFactory.getLog(ProtocolConverter.class);
    private ConnectionFactory connectionFactory;
    private final StompHandler outputHandler;
    private Connection connection;
    private StompSession defaultSession;
    private StompSession clientAckSession;
    private final Map<String,StompSession> transactedSessions = new ConcurrentHashMap<String,StompSession>();
    private final Map subscriptions = new ConcurrentHashMap();
    private final Map messages = new ConcurrentHashMap();

    public ProtocolConverter(ConnectionFactory connectionFactory, StompHandler outputHandler) {
        this.connectionFactory = connectionFactory;
        this.outputHandler = outputHandler;
    }

    public ConnectionFactory getConnectionFactory() {
        return connectionFactory;
    }

    public StompHandler getOutputHandler() {
        return outputHandler;
    }

    public synchronized void close() throws JMSException {
        try {
            // lets close all the sessions first
            JMSException firstException = null;
            Collection<StompSession> sessions = new ArrayList<StompSession>(transactedSessions.values());
            if (defaultSession != null) {
                sessions.add(defaultSession);
            }
            if (clientAckSession != null) {
                sessions.add(clientAckSession);
            }
            for (StompSession session : sessions) {
                try {
                    if (log.isDebugEnabled()) {
                        log.debug("Closing session: " + session + " with ack mode: " + session.getSession().getAcknowledgeMode());
                    }
                    session.close();
                }
                catch (JMSException e) {
                    if (firstException == null) {                                           
                        firstException = e;
                    }
                }
            }

            // now the connetion
            if (connection != null) {
                connection.close();
            }

            if (firstException != null) {
                throw firstException;
            }
        }
        finally {
            connection = null;
            defaultSession = null;
            clientAckSession = null;
            transactedSessions.clear();
            subscriptions.clear();
            messages.clear();
        }
    }

    /**
     * Process a Stomp Frame
     */
    public void onStompFrame(StompFrame command) throws Exception {
        try {
            if (log.isDebugEnabled()) {
                log.debug(">>>> " + command.getAction() + " headers: " + command.getHeaders());
            }
            
            if (command.getClass() == StompFrameError.class) {
                throw ((StompFrameError) command).getException();
            }

            String action = command.getAction();
            if (action.startsWith(Stomp.Commands.SEND)) {
                onStompSend(command);
            }
            else if (action.startsWith(Stomp.Commands.ACK)) {
                onStompAck(command);
            }
            else if (action.startsWith(Stomp.Commands.BEGIN)) {
                onStompBegin(command);
            }
            else if (action.startsWith(Stomp.Commands.COMMIT)) {
                onStompCommit(command);
            }
            else if (action.startsWith(Stomp.Commands.ABORT)) {
                onStompAbort(command);
            }
            else if (action.startsWith(Stomp.Commands.SUBSCRIBE)) {
                onStompSubscribe(command);
            }
            else if (action.startsWith(Stomp.Commands.UNSUBSCRIBE)) {
                onStompUnsubscribe(command);
            }
            else if (action.startsWith(Stomp.Commands.CONNECT)) {
                onStompConnect(command);
            }
            else if (action.startsWith(Stomp.Commands.DISCONNECT)) {
                onStompDisconnect(command);
            }
            else {
                throw new ProtocolException("Unknown STOMP action: " + action);
            }
        }
        catch (Exception e) {

            // Let the stomp client know about any protocol errors.
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            PrintWriter stream = new PrintWriter(new OutputStreamWriter(baos, "UTF-8"));
            e.printStackTrace(stream);
            stream.close();

            HashMap headers = new HashMap();
            headers.put(Stomp.Headers.Error.MESSAGE, e.getMessage());

            final String receiptId = (String) command.getHeaders().get(Stomp.Headers.RECEIPT_REQUESTED);
            if (receiptId != null) {
                headers.put(Stomp.Headers.Response.RECEIPT_ID, receiptId);
            }

            StompFrame errorMessage = new StompFrame(Stomp.Responses.ERROR, headers, baos.toByteArray());
            sendToStomp(errorMessage);

            // TODO need to do anything else? Should we close the connection?
        }
    }

    public void onException(Exception e) {
        log.error("Caught: " + e, e);
    }

    public void addMessageToAck(Message message) throws JMSException {
        messages.put(message.getJMSMessageID(), message);
    }

    // Implemenation methods
    //-------------------------------------------------------------------------
    protected void onStompConnect(StompFrame command) throws Exception {
        if (connection != null) {
            throw new ProtocolException("Allready connected.");
        }

        final Map headers = command.getHeaders();
        String login = (String) headers.get(Stomp.Headers.Connect.LOGIN);
        String passcode = (String) headers.get(Stomp.Headers.Connect.PASSCODE);
        String clientId = (String) headers.get(Stomp.Headers.Connect.CLIENT_ID);

        ConnectionFactory factory = getConnectionFactory();
        IntrospectionSupport.setProperties(factory, headers, "factory.");

        if (login != null) {
            connection = factory.createConnection(login, passcode);
        }
        else {
            connection = factory.createConnection();
        }
        if (clientId != null) {
            connection.setClientID(clientId);
        }
        IntrospectionSupport.setProperties(connection, headers, "connection.");

        connection.start();

        Map responseHeaders = new HashMap();

        responseHeaders.put(Stomp.Headers.Connected.SESSION, connection.getClientID());
        String requestId = (String) headers.get(Stomp.Headers.Connect.REQUEST_ID);
        if (requestId == null) {
            // TODO legacy
            requestId = (String) headers.get(Stomp.Headers.RECEIPT_REQUESTED);
        }
        if (requestId != null) {
            // TODO legacy
            responseHeaders.put(Stomp.Headers.Connected.RESPONSE_ID, requestId);
            responseHeaders.put(Stomp.Headers.Response.RECEIPT_ID, requestId);
        }

        StompFrame sc = new StompFrame();
        sc.setAction(Stomp.Responses.CONNECTED);
        sc.setHeaders(responseHeaders);
        sendToStomp(sc);
    }

    protected void onStompDisconnect(StompFrame command) throws Exception {
        checkConnected();
        close();
    }

    protected void onStompSend(StompFrame command) throws Exception {
        checkConnected();

        Map headers = command.getHeaders();
        String stompTx = (String) headers.get(Stomp.Headers.TRANSACTION);

        StompSession session;
        if (stompTx != null) {
            session = getExistingTransactedSession(stompTx);
        }
        else {
            session = getDefaultSession();
        }

        session.sendToJms(command);
        sendResponse(command);
    }

    protected void onStompBegin(StompFrame command) throws Exception {
        checkConnected();

        Map headers = command.getHeaders();

        String stompTx = (String) headers.get(Stomp.Headers.TRANSACTION);

        if (stompTx == null) {
            throw new ProtocolException("Must specify the transaction you are beginning");
        }

        StompSession session = getTransactedSession(stompTx);
        if (session != null) {
            throw new ProtocolException("The transaction was already started: " + stompTx);
        }
        session = createTransactedSession(stompTx);
        setTransactedSession(stompTx, session);

        sendResponse(command);
    }

    protected void onStompCommit(StompFrame command) throws Exception {
        checkConnected();

        Map headers = command.getHeaders();
        String stompTx = (String) headers.get(Stomp.Headers.TRANSACTION);
        if (stompTx == null) {
            throw new ProtocolException("Must specify the transaction you are committing");
        }

        StompSession session = getExistingTransactedSession(stompTx);
        session.getSession().commit();
        considerClosingTransactedSession(session, stompTx);
        sendResponse(command);
    }

    protected void onStompAbort(StompFrame command) throws Exception {
        checkConnected();
        Map headers = command.getHeaders();

        String stompTx = (String) headers.get(Stomp.Headers.TRANSACTION);
        if (stompTx == null) {
            throw new ProtocolException("Must specify the transaction you are committing");
        }

        StompSession session = getExistingTransactedSession(stompTx);
        session.getSession().rollback();
        considerClosingTransactedSession(session, stompTx);
        sendResponse(command);
    }

    protected void onStompSubscribe(StompFrame command) throws Exception {
        checkConnected();

        Map headers = command.getHeaders();
        String stompTx = (String) headers.get(Stomp.Headers.TRANSACTION);

        StompSession session;
        if (stompTx != null) {
            session = getExistingTransactedSession(stompTx);
        }
        else {
            String ackMode = (String) headers.get(Stomp.Headers.Subscribe.ACK_MODE);
            if (ackMode != null && Stomp.Headers.Subscribe.AckModeValues.CLIENT.equals(ackMode)) {
                session = getClientAckSession();
            }
            else {
                session = getDefaultSession();
            }
        }

        String subscriptionId = (String) headers.get(Stomp.Headers.Subscribe.ID);
        if (subscriptionId == null) {
            subscriptionId = createSubscriptionId(headers);
        }

        StompSubscription subscription = (StompSubscription) subscriptions.get(subscriptionId);
        if (subscription != null) {
            throw new ProtocolException("There already is a subscription for: " + subscriptionId + ". Either use unique subscription IDs or do not create multiple subscriptions for the same destination");
        }
        subscription = new StompSubscription(session, subscriptionId, command);
        subscriptions.put(subscriptionId, subscription);
        sendResponse(command);
    }

    protected void onStompUnsubscribe(StompFrame command) throws Exception {
        checkConnected();
        Map headers = command.getHeaders();

        String destinationName = (String) headers.get(Stomp.Headers.Unsubscribe.DESTINATION);
        String subscriptionId = (String) headers.get(Stomp.Headers.Unsubscribe.ID);

        if (subscriptionId == null) {
            if (destinationName == null) {
                throw new ProtocolException("Must specify the subscriptionId or the destination you are unsubscribing from");
            }
            subscriptionId = createSubscriptionId(headers);
        }

        StompSubscription subscription = (StompSubscription) subscriptions.remove(subscriptionId);
        if (subscription == null) {
            throw new ProtocolException("Cannot unsubscribe as mo subscription exists for id: " + subscriptionId);
        }
        subscription.close();
        sendResponse(command);
    }

    protected void onStompAck(StompFrame command) throws Exception {
        checkConnected();

        // TODO: acking with just a message id is very bogus
        // since the same message id could have been sent to 2 different subscriptions
        // on the same stomp connection. For example, when 2 subs are created on the same topic.

        Map headers = command.getHeaders();
        String messageId = (String) headers.get(Stomp.Headers.Ack.MESSAGE_ID);
        if (messageId == null) {
            throw new ProtocolException("ACK received without a message-id to acknowledge!");
        }

        Message message = (Message) messages.remove(messageId);
        if (message == null) {
            throw new ProtocolException("No such message for message-id: " + messageId);
        }
        message.acknowledge();
        sendResponse(command);
    }

    protected void checkConnected() throws ProtocolException {
        if (connection == null) {
            throw new ProtocolException("Not connected.");
        }
    }

    /**
     * Auto-create a subscription ID using the destination
     */
    protected String createSubscriptionId(Map headers) {
        return "/subscription-to/" + headers.get(Stomp.Headers.Subscribe.DESTINATION);
    }

    protected StompSession getDefaultSession() throws JMSException {
        if (defaultSession == null) {
            defaultSession = createSession(Session.AUTO_ACKNOWLEDGE);
        }
        return defaultSession;
    }

    protected StompSession getClientAckSession() throws JMSException {
        if (clientAckSession == null) {
            clientAckSession = createSession(Session.CLIENT_ACKNOWLEDGE);
        }
        return clientAckSession;
    }

    /**
     * Returns the transacted session for the given ID or throws an exception if there is no such session
     */
    protected StompSession getExistingTransactedSession(String stompTx) throws ProtocolException, JMSException {
        StompSession session = getTransactedSession(stompTx);
        if (session == null) {
            throw new ProtocolException("Invalid transaction id: " + stompTx);
        }
        return session;
    }

    protected StompSession getTransactedSession(String stompTx) throws ProtocolException, JMSException {
        return (StompSession) transactedSessions.get(stompTx);
    }

    protected void setTransactedSession(String stompTx, StompSession session) {
        transactedSessions.put(stompTx, session);
    }

    protected StompSession createSession(int ackMode) throws JMSException {
        Session session = connection.createSession(false, ackMode);
        if (log.isDebugEnabled()) {
            log.debug("Created session with ack mode: " + session.getAcknowledgeMode());
        }
        return new StompSession(this, session);
    }

    protected StompSession createTransactedSession(String stompTx) throws JMSException {
        Session session = connection.createSession(true, Session.SESSION_TRANSACTED);
        return new StompSession(this, session);
    }

    protected void sendResponse(StompFrame command) throws Exception {
        final String receiptId = (String) command.getHeaders().get(Stomp.Headers.RECEIPT_REQUESTED);
        // A response may not be needed.
        if (receiptId != null) {
            StompFrame sc = new StompFrame();
            sc.setAction(Stomp.Responses.RECEIPT);
            sc.setHeaders(new HashMap(1));
            sc.getHeaders().put(Stomp.Headers.Response.RECEIPT_ID, receiptId);
            sendToStomp(sc);
        }
    }

    protected void sendToStomp(StompFrame frame) throws Exception {
        if (log.isDebugEnabled()) {
            log.debug("<<<< " + frame.getAction() + " headers: " + frame.getHeaders());
        }
        outputHandler.onStompFrame(frame);
    }

    /**
     * A provider may wish to eagerly close transacted sessions when they are no longer used.
     * Though a better option would be to just time them out after they have no longer been used.
     */
    protected void considerClosingTransactedSession(StompSession session, String stompTx) {
    }
}
