//Source: https://github.com/dotnet/MQTTnet

// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

// ReSharper disable UnusedType.Global
// ReSharper disable UnusedMember.Global
// ReSharper disable InconsistentNaming
// ReSharper disable EmptyConstructor
// ReSharper disable MemberCanBeMadeStatic.Local

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MQTTnet;
using MQTTnet.AspNetCore;
using MQTTnet.Server;
using System;
using System.Text;
using System.Threading.Tasks;

namespace MQTTnet.Samples.Server
{
    public static class Server_ASP_NET_Samples
    {
        public static Task Start_Server_With_WebSockets_Support()
        {
            var host = Host.CreateDefaultBuilder(Array.Empty<string>())
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.UseKestrel(o =>
                    {
                        o.ListenAnyIP(1883, l => l.UseMqtt());
                        o.ListenAnyIP(5000);
                    });

                    webBuilder.UseStartup<Startup>();
                });

            return host.RunConsoleAsync();
        }
    }

    sealed class MqttController
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

    sealed class Startup
    {
        public void Configure(IApplicationBuilder app, IWebHostEnvironment environment, MqttController mqttController)
        {
            app.UseRouting();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapConnectionHandler<MqttConnectionHandler>("/mqtt", httpConnectionDispatcherOptions =>
                {
                    httpConnectionDispatcherOptions.WebSockets.SubProtocolSelector =
                        protocolList => protocolList.FirstOrDefault() ?? string.Empty;
                });
            });

            app.UseMqttServer(server =>
            {
                server.ValidatingConnectionAsync += mqttController.ValidateConnection;
                server.ClientConnectedAsync += mqttController.OnClientConnected;
                server.InterceptingPublishAsync += mqttController.OnMessageReceived;
            });
        }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddHostedMqttServer(optionsBuilder =>
            {
                optionsBuilder.WithDefaultEndpoint();
            });

            services.AddMqttConnectionHandler();
            services.AddConnections();

            services.AddSingleton<MqttController>();
        }
    }
}
