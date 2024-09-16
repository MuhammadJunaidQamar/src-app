using Microsoft.AspNetCore.Mvc;
using MQTTnet.Server;
using src.Models;
using System.Text;
using System.Timers;

namespace src.Controllers
{
    public class MqttController : Controller
    {
        // To store the time when the last message was received
        private static DateTime _lastMessageTime;

        // To store the client ID of the ESP32, initialized to an empty string
        private static string _lastClientId = string.Empty;

        // Timer to periodically check if the client is offline
        private static System.Timers.Timer _offlineCheckTimer;

        // Timeout period (in milliseconds) after which the client is considered offline if no message is received
        private static readonly int OfflineTimeout = 5000; // 5 seconds timeout for offline detection

        public MqttController()
        {
            // Set up a timer to check for ESP32 offline status
            _offlineCheckTimer = new System.Timers.Timer(OfflineTimeout);

            // Hooking up the Elapsed event of the timer to the CheckClientOfflineStatus method
            _offlineCheckTimer.Elapsed += CheckClientOfflineStatus;

            // Timer will continue running periodically (AutoReset set to true)
            _offlineCheckTimer.AutoReset = true;

            // Start the timer
            _offlineCheckTimer.Start();
        }

        // This method is triggered when a new client connects to the MQTT broker
        public Task OnClientConnected(ClientConnectedEventArgs eventArgs)
        {
            // Store the client ID of the connected ESP32
            _lastClientId = eventArgs.ClientId;

            // Log client connection
            Console.WriteLine($"Client '{eventArgs.ClientId}' connected.");
            return Task.CompletedTask;
        }

        // This method is triggered when a client disconnects from the MQTT broker
        public Task OnClientDisconnected(ClientDisconnectedEventArgs eventArgs)
        {
            // Log client disconnection
            Console.WriteLine($"Client '{eventArgs.ClientId}' disconnected.");

            // If the disconnected client is the ESP32, mark it as offline
            if (eventArgs.ClientId == _lastClientId)
            {
                LastMessageModel.LastMessage = string.Empty; // Indicating that the ESP32 is offline
            }
            return Task.CompletedTask;
        }

        // This method is triggered when a client attempts to connect to the MQTT broker (validating connection)
        public Task ValidateConnection(ValidatingConnectionEventArgs eventArgs)
        {
            // Log that the connection request from the client is accepted
            Console.WriteLine($"Client '{eventArgs.ClientId}' wants to connect. Accepting!");
            return Task.CompletedTask;
        }

        // This method is triggered when the MQTT server receives a message from a client
        public Task OnMessageReceived(InterceptingPublishEventArgs eventArgs)
        {
            // Extract the payload (message) from the event arguments
            var payload = eventArgs.ApplicationMessage.PayloadSegment;

            // Convert the payload to a string and update the LastMessageModel with the received message
            LastMessageModel.LastMessage = Encoding.UTF8.GetString(payload);

            // Update the timestamp for the last received message
            _lastMessageTime = DateTime.Now;

            // Log the message received on the specified topic
            Console.WriteLine($"Message received on topic '{eventArgs.ApplicationMessage.Topic}': {LastMessageModel.LastMessage}");
            return Task.CompletedTask;
        }

        // This method checks whether the ESP32 client is offline by comparing the last message time with the current time
        private void CheckClientOfflineStatus(object sender, ElapsedEventArgs e)
        {
            // Check if the difference between the current time and the last message time exceeds the timeout
            if ((DateTime.Now - _lastMessageTime).TotalMilliseconds > OfflineTimeout)
            {
                // If no message has been received within the timeout period, log that the client is offline
                Console.WriteLine($"ESP32 client '{_lastClientId}' is offline (no message received within {OfflineTimeout / 1000} seconds).");

                // Mark the ESP32 as offline by clearing the LastMessageModel
                LastMessageModel.LastMessage = string.Empty; // Use empty string instead of null
            }
        }
    }
}
