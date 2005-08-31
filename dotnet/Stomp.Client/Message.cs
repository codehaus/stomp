using System.Collections;

namespace Stomp.Client
{
	public class Message
	{
		private readonly string body;
		private readonly string destination;
		private readonly IDictionary headers;

		public Message(string destination, string body, IDictionary headers)
		{
			this.body = body;
			this.destination = destination;
			this.headers = headers;
		}

		public string Body
		{
			get { return body; }
		}

		public string Destination
		{
			get { return destination; }
		}

		public string this[string key] 
		{
			get { return (string) headers[key]; }
		}
	}
}
