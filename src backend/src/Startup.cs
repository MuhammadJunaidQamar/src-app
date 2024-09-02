using MQTTnet.AspNetCore;
using src.Controllers;

namespace src
{
    public class StartUp
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
