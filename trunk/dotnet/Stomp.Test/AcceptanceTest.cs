using NUnit.Framework;
using Stomp.Client;

namespace Stomp.Test
{
	[TestFixture]
	public class AcceptanceTest
	{
		[Test]
		public void SendAndSyncReceive() 
		{
			using(StompConnection stomp = new StompConnection("localhost", 61626)) 
			{
				stomp.Subscribe("/queue/test");
				stomp.Send("/queue/test", "Hello world!");
				Message message = stomp.WaitForMessage();
				Assert.AreEqual("Hello world!", message.Body);
			}
		}
	}
}
