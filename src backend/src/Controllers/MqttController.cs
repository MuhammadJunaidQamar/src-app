using Microsoft.AspNetCore.Mvc;
using MQTTnet.Server;
using System.Text;

namespace src.Controllers
{
    public class MqttController : Controller
    {

        public MqttController()
        {
        }

        public Task OnClientConnected(ClientConnectedEventArgs eventArgs)
        {
            Console.WriteLine($"Client '{eventArgs.ClientId}' connected.");
            return Task.CompletedTask;
        }

        public Task ValidateConnection(ValidatingConnectionEventArgs eventArgs)
        {
            Console.WriteLine($"Client '{eventArgs.ClientId}' wants to connect. Accepting!");
            return Task.CompletedTask;
        }

        // This method is triggered when the server receives a message from a client.
        public Task OnMessageReceived(InterceptingPublishEventArgs eventArgs)
        {
            var payload = eventArgs.ApplicationMessage.Payload;
            var message = Encoding.UTF8.GetString(payload);

            Console.WriteLine($"Message received on topic '{eventArgs.ApplicationMessage.Topic}': {message}");
            return Task.CompletedTask;
        }
    }
}
