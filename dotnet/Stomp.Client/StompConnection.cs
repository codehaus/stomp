using System;
using System.Collections;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace Stomp.Client
{
	public class StompConnection : IDisposable
	{
		private readonly object transmissionLock = new object();
		private readonly Socket socket;
		private readonly TextWriter socketWriter;
		private readonly TextReader socketReader;
	
		public delegate void MessageDelegate(string destination, string body, IDictionary headers);
	
		public StompConnection(string host, int port, string login, string passcode)
		{
			//@listeners = {}
			socket = Connect(host, port);
			socketWriter = new StreamWriter(new NetworkStream(socket));
			socketReader = new StreamReader(new NetworkStream(socket));

			Transmit("CONNECT", null, null, "login", login, "passcode", passcode);
			Packet ack = Receive();
			if (ack.command != "CONNECTED") 
			{
				throw new ApplicationException("Could not connect : " + ack);
			}
		}
	
		public StompConnection(string host, int port) : this(host, port, "", "")
		{
		}

		private Socket Connect(string host, int port) 
		{
			// Looping through the AddressList allows different type of connections to be tried 
			// (IPv4, IPv6 and whatever else may be available).
			IPHostEntry hostEntry = Dns.Resolve(host);
			foreach(IPAddress address in hostEntry.AddressList)
			{
				Socket socket = new Socket(address.AddressFamily, SocketType.Stream, ProtocolType.Tcp);
				socket.Connect(new IPEndPoint(address, port));
				if (socket.Connected) 
				{
					return socket;
				}
			}
			throw new SocketException();
		}

		public void Dispose() 
		{
			Transmit("DISCONNECT", null, null);
			socket.Close();
			socketWriter.Close();
			socketReader.Close();
		}

		public void Send(string destination, string body, IDictionary headers) 
		{
			Transmit("SEND", body, headers, "destination", destination);
		}
	
		public void Send(string destination, string body) 
		{
			Send(destination, body, null);
		}
	
		public void Begin() 
		{
			Transmit("BEGIN", null, null);
		}	
	
		public void Commit() 
		{
			Transmit("COMMIT", null, null);
		}	
	
		public void Abort() 
		{
			Transmit("ABORT", null, null);
		}	
	
		public void Subscribe(string destination, IDictionary headers) 
		{
			Transmit("SUBSCRIBE", null, headers, "destination", destination);
		}
	
		public void Subscribe(string destination) 
		{
			Subscribe(destination, null);
		}
	
		public void Unsubscribe(string destination, IDictionary headers) 
		{
			// James says: if you supplied a consumerID in the message then you will still be subbed
			Transmit("UNSUBSCRIBE", null, headers, "destination", destination);
		}
	
		public void Unsubscribe(string destination) 
		{
			Unsubscribe(destination, null);
		}
	
		private void Transmit(string command, string body, IDictionary headers, params string[] additionalHeaderPairs) 
		{
			lock(transmissionLock)
			{
				socketWriter.WriteLine(command);
				for (int i = 0; i < additionalHeaderPairs.Length; i+=2) 
				{
					string key = additionalHeaderPairs[i];
					string val = additionalHeaderPairs[i + 1];
					socketWriter.WriteLine("{0}:{1}", key, val);
					if (headers != null) 
					{
						headers.Remove(key); // just in case headers dictionary contains duplicate entry
					}
				}
				if (headers != null) 
				{
					foreach(object key in headers.Keys) 
					{
						object val = headers[key];
						socketWriter.WriteLine("{0}:{1}", key, val);
					}
				}
				socketWriter.WriteLine();
				socketWriter.WriteLine(body);
				socketWriter.WriteLine('\u0000');
				socketWriter.Flush();
			}
		}
	
		public Message WaitForMessage()
		{
			Packet packet = Receive();
			if (packet.command == "MESSAGE") 
			{
				return new Message((string) packet.headers["destination"], packet.body, packet.headers);
			}
			else 
			{
				return null;
			}
		}

		private Packet Receive() 
		{
			Packet packet = new Packet();
			packet.command = socketReader.ReadLine(); // MESSAGE, ERROR or RECEIPT

			//return if command =~ /\A\s*\Z/

			string line;
			while((line = socketReader.ReadLine()) != "") 
			{
				string[] split = line.Split(new char[] {':'}, 2);
				packet.headers[split[0]] = split[1];
			}

			StringBuilder body = new StringBuilder();
			int nextChar;
			while((nextChar = socketReader.Read()) != 0) 
			{
				body.Append((char)nextChar);
			}
			packet.body = body.ToString().TrimEnd('\r', '\n');

			Console.Out.WriteLine(packet);
			return packet;
		}

		private class Packet 
		{
			public string command;
			public string body;
			public IDictionary headers = new Hashtable();

			public override string ToString()
			{
				StringBuilder result = new StringBuilder();
				result.Append(command).Append(Environment.NewLine);
				foreach (DictionaryEntry entry in headers)
				{
					result.Append(entry.Key).Append(':').Append(entry.Value).Append(Environment.NewLine);
				}
				result.Append("----").Append(Environment.NewLine);;
				result.Append(body);
				result.Append("====").Append(Environment.NewLine);
				return result.ToString();
			}
		}

	}
}
