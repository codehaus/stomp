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

import org.codehaus.stomp.StompHandler;
import org.codehaus.stomp.StompHandlerFactory;
import org.codehaus.stomp.tcp.TcpTransportServer;
import org.codehaus.stomp.util.ServiceSupport;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import javax.jms.ConnectionFactory;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.net.ServerSocketFactory;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.Hashtable;

/**
 * This class represents a service which accepts STOMP socket connections and binds them to JMS operations
 *
 * @version $Revision$
 */
public class StompConnect extends ServiceSupport implements StompHandlerFactory {
    private static final transient Log log = LogFactory.getLog(StompConnect.class);

    private ConnectionFactory connectionFactory;
    private String uri = "tcp://localhost:61613";
    private URI location;
    private ServerSocketFactory serverSocketFactory;
    private TcpTransportServer tcpServer;
    private InitialContext initialContext;
    private String jndiName = "ConnectionFactory";
    private Hashtable jndiEnvironment = new Hashtable();

    public StompConnect() {
    }

    public StompConnect(ConnectionFactory connectionFactory) {
        this.connectionFactory = connectionFactory;
    }

    public StompHandler createStompHandler(StompHandler outputHandler) throws NamingException {
        ConnectionFactory factory = getConnectionFactory();
        if (factory == null) {
            throw new IllegalArgumentException("No ConnectionFactory is configured!");
        }
        return new ProtocolConverter(factory, outputHandler);
    }

    /**
     * Joins with the background thread until the transport is stopped
     */
    public void join() throws IOException, URISyntaxException, InterruptedException {
        getTcpServer().join();
    }

    // Properties
    //-------------------------------------------------------------------------
    public ConnectionFactory getConnectionFactory() throws NamingException {
        if (connectionFactory == null) {
            connectionFactory = createConnectionFactory();
        }
        return connectionFactory;
    }

    /**
     * Sets the JMS connection factory to use to communicate with
     */
    public void setConnectionFactory(ConnectionFactory connectionFactory) {
        this.connectionFactory = connectionFactory;
    }

    public String getUri() {
        return uri;
    }

    /**
     * Sets the URI string for the hostname/IP address and port to listen on for STOMP frames
     */
    public void setUri(String uri) {
        this.uri = uri;
    }

    public URI getLocation() throws URISyntaxException {
        if (location == null) {
            location = new URI(uri);
        }
        return location;
    }

    /**
     * Sets the URI for the hostname/IP address and port to listen on for STOMP frames
     */
    public void setLocation(URI location) {
        this.location = location;
    }

    public ServerSocketFactory getServerSocketFactory() {
        if (serverSocketFactory == null) {
            serverSocketFactory = ServerSocketFactory.getDefault();
        }
        return serverSocketFactory;
    }

    /**
     * Sets the {@link ServerSocketFactory} to use to listen for STOMP frames
     */
    public void setServerSocketFactory(ServerSocketFactory serverSocketFactory) {
        this.serverSocketFactory = serverSocketFactory;
    }

    public TcpTransportServer getTcpServer() throws IOException, URISyntaxException {
        if (tcpServer == null) {
            tcpServer = createTcpServer();
        }
        return tcpServer;
    }

    public void setTcpServer(TcpTransportServer tcpServer) {
        this.tcpServer = tcpServer;
    }

    public InitialContext getInitialContext() throws NamingException {
        if (initialContext == null) {
            initialContext = new InitialContext(jndiEnvironment);
        }
        return initialContext;
    }

    /**
     * Allows an initial context to be configured which is used if no explicit {@link ConnectionFactory}
     * is configured via the {@link #setConnectionFactory(ConnectionFactory)} method
     */
    public void setInitialContext(InitialContext initialContext) {
        this.initialContext = initialContext;
    }

    public String getJndiName() {
        return jndiName;
    }

    /**
     * Allows the JNDI name to be configured which is used to perform a JNDI lookup
     * if no explicit {@link ConnectionFactory}
     * is configured via the {@link #setConnectionFactory(ConnectionFactory)} method
     */
    public void setJndiName(String jndiName) {
        this.jndiName = jndiName;
    }

    public Hashtable getJndiEnvironment() {
        return jndiEnvironment;
    }

    /**
     * Sets the JNDI environment used if an {@link InitialContext} is lazily created if no explicit {@link ConnectionFactory}
     * is configured via the {@link #setConnectionFactory(ConnectionFactory)} method
     */
    public void setJndiEnvironment(Hashtable jndiEnvironment) {
        this.jndiEnvironment = jndiEnvironment;
    }

    // Implementation methods
    //-------------------------------------------------------------------------
    protected void doStart() throws Exception {
        ConnectionFactory factory = getConnectionFactory();
        if (factory == null) {
            throw new IllegalArgumentException("No ConnectionFactory has been configured!");
        }

        getTcpServer().start();
    }

    protected void doStop() throws Exception {
        getTcpServer().stop();
    }

    protected TcpTransportServer createTcpServer() throws IOException, URISyntaxException {
        return new TcpTransportServer(this, getLocation(), getServerSocketFactory());
    }

    /**
     * Factory method to lazily create a {@link ConnectionFactory} if one is not explicitly configured.
     * By default lets try looking in JNDI
     */
    protected ConnectionFactory createConnectionFactory() throws NamingException {
        String name = getJndiName();
        log.info("Looking up name: " + name + " in JNDI InitialContext for JMS ConnectionFactory");

        Object value = getInitialContext().lookup(name);
        if (value == null) {
            throw new IllegalArgumentException("No ConnectionFactory object is available in JNDI at name: " + name);
        }
        if (value instanceof ConnectionFactory) {
            return (ConnectionFactory) value;
        }
        else {
            throw new IllegalArgumentException("The object in JNDI at name: " + name
                    + " cannot be cast to ConnectionFactory. "
                    + "Either a JNDI configuration issue or you have multiple JMS API jars on your classpath. " +
                    "Actual Object was: " + value);
        }
    }
}
