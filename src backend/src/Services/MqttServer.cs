//Source: https://github.com/dotnet/MQTTnet

// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.
// See the LICENSE file in the project root for more information.

// ReSharper disable UnusedType.Global
// ReSharper disable UnusedMember.Global
// ReSharper disable InconsistentNaming
// ReSharper disable EmptyConstructor
// ReSharper disable MemberCanBeMadeStatic.Local

using MQTTnet.AspNetCore;

namespace src.Services
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

                    webBuilder.UseStartup<StartUp>();

                    webBuilder.UseUrls("http://localhost:5000");
                });

            return host.RunConsoleAsync();
        }
    }
}
