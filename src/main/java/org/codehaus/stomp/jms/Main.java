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

/**
 * A Stomp Broker using StompConnect and the current JNDI provider found on the classpath (usually via a jndi.properties file)
 * to resolve the current JMS Provider (the ConnectionFactory).
 *
 * @version $Revision$
 */
public class Main {
    protected StompConnect connect = new StompConnect();

    public static void main(String[] args) {
        try {
            Main main = new Main();
            if (main.parseArguments(args)) {
                main.run();
            }
        }
        catch (Exception e) {
            System.out.println("Caught: " + e);
            e.printStackTrace();
        }
    }

    public void run() throws Exception {
        connect.start();
        connect.join();
    }

    public boolean parseArguments(String[] args) {
        if (args.length > 0) {
            String arg = args[0];
            if (arg.startsWith("?") || arg.equals("-?") || arg.equals("-h") || arg.startsWith("--h")) {
                printOptions();
                return false;
            }
            connect.setUri(arg);

            if (args.length > 1) {
                connect.setJndiName(args[1]);
            }
        }
        return true;
    }

    protected void printOptions() {
        System.out.println("StompConnect");
        System.out.println();
        System.out.println("Arguments: <uri> <jndiName>");
        System.out.println("    uri      = the host and port to listen on for STOMP traffic");
        System.out.println("    jndiName = the name in the default JNDI context to look for the ConnectionFactory");
        System.out.println();
        System.out.println("For more help see http://stomp.codehaus.org/StompConnect");
    }
}
