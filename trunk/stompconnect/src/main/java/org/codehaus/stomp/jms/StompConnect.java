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

import javax.jms.ConnectionFactory;
import javax.net.ServerSocketFactory;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;

/**
 * This class represents a service which accepts STOMP socket connections and binds them to JMS operations
 *
 * @version $Revision$
 */
public class StompConnect extends ServiceSupport implements StompHandlerFactory {
    private ConnectionFactory connectionFactory;
    private String uri = "tcp://localhost:61613";
    private URI location;
    private ServerSocketFactory serverSocketFactory;
    private TcpTransportServer tcpServer;

    public StompHandler createStompHandler(StompHandler outputHandler) {
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
    public ConnectionFactory getConnectionFactory() {
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
     * Sets the URL for the hostname/IP address and port to listen on
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

    public void setLocation(URI location) {
        this.location = location;
    }

    public ServerSocketFactory getServerSocketFactory() {
        if (serverSocketFactory == null) {
            serverSocketFactory = ServerSocketFactory.getDefault();
        }
        return serverSocketFactory;
    }

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

    // Implementation methods
    //-------------------------------------------------------------------------
    protected void doStart() throws Exception {
        getTcpServer().start();
    }

    protected void doStop() throws Exception {
        getTcpServer().stop();
    }

    protected TcpTransportServer createTcpServer() throws IOException, URISyntaxException {
        return new TcpTransportServer(this, getLocation(), getServerSocketFactory());
    }
}
