using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Connections;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Server.Kestrel.Transport.Sockets;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using OpenZiti;

namespace ZoSdk;

/// <summary>
/// Serves HTTP over a Ziti listener on ZITI_SERVICE.
/// GET /      -> 200 {"lang":"cs","host":"<hostname>"}
/// GET /healthz -> 200 "ok"
/// </summary>
public static class HttpServer
{
    public static async Task Run()
    {
        string identityFile = Env.IdentityFile;
        string serviceName  = Env.ServiceName;
        string lang         = Environment.GetEnvironmentVariable("SELF_LANG") ?? "cs";

        Console.Error.WriteLine($"[http-server] identity={identityFile} service={serviceName}");

        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { Args = [] });
        builder.Logging.ClearProviders();

        builder.WebHost.ConfigureKestrel(k =>
        {
            k.Listen(new ZitiEndPoint(identityFile, serviceName));
        });

        builder.Services.AddSingleton<IConnectionListenerFactory>(
            sp => new ZitiConnectionListenerFactory(
                sp.GetRequiredService<ILoggerFactory>(), identityFile, serviceName));

        var app = builder.Build();

        app.MapGet("/", () =>
        {
            string host = Dns.GetHostName();
            return Results.Json(new { lang, host });
        });

        app.MapGet("/healthz", () => Results.Text("ok"));

        Console.Error.WriteLine($"[http-server] serving on Ziti service '{serviceName}'");
        await app.RunAsync();
    }
}

// ---------------------------------------------------------------------------
// Minimal Kestrel transport that binds a Ziti socket.
// ---------------------------------------------------------------------------

internal sealed class ZitiEndPoint : EndPoint
{
    public string IdentityFile { get; }
    public string ServiceName  { get; }
    public ZitiEndPoint(string identityFile, string serviceName)
    {
        IdentityFile = identityFile;
        ServiceName  = serviceName;
    }
    public override string ToString() => $"ziti://{ServiceName}";
}

internal sealed class ZitiConnectionListenerFactory : IConnectionListenerFactory
{
    private readonly ILoggerFactory _loggerFactory;
    private readonly string _identityFile;
    private readonly string _serviceName;
    private readonly IConnectionListenerFactory _fallback;

    public ZitiConnectionListenerFactory(ILoggerFactory loggerFactory, string identityFile, string serviceName)
    {
        _loggerFactory = loggerFactory;
        _identityFile  = identityFile;
        _serviceName   = serviceName;
        _fallback = new SocketTransportFactory(
            Microsoft.Extensions.Options.Options.Create(new SocketTransportOptions()),
            loggerFactory);
    }

    public ValueTask<IConnectionListener> BindAsync(EndPoint endpoint, CancellationToken ct = default)
    {
        if (endpoint is ZitiEndPoint ze)
        {
            var ctx    = Env.LoadContext(ze.IdentityFile);
            var server = new ZitiSocket(SocketType.Stream);
            API.Bind(server, ctx, ze.ServiceName, "");
            API.Listen(server, 100);
            return new ValueTask<IConnectionListener>(
                new ZitiListener(server, ctx, ze, _loggerFactory));
        }
        return _fallback.BindAsync(endpoint, ct);
    }
}

internal sealed class ZitiListener : IConnectionListener
{
    private readonly ZitiSocket _server;
    private readonly ZitiContext _ctx;   // keep alive
    private readonly ZitiEndPoint _ep;
    private readonly SocketConnectionContextFactory _factory;
    private bool _disposed;

    public EndPoint EndPoint => _ep;

    public ZitiListener(ZitiSocket server, ZitiContext ctx, ZitiEndPoint ep, ILoggerFactory lf)
    {
        _server  = server;
        _ctx     = ctx;
        _ep      = ep;
        _factory = new SocketConnectionContextFactory(
            new SocketConnectionFactoryOptions(),
            lf.CreateLogger<ZitiListener>());
    }

    public async ValueTask<ConnectionContext?> AcceptAsync(CancellationToken ct = default)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                var sock  = _server.ToSocket();
                bool ready = sock.Poll(500_000, SelectMode.SelectRead); // 500 ms
                if (!ready) continue;

                var client = API.Accept(_server, out _);
                return _factory.Create(client.ToSocket());
            }
            catch (SocketException ex) when (ex.SocketErrorCode == SocketError.WouldBlock)
            {
                await Task.Delay(1, ct);
            }
            catch (ObjectDisposedException)
            {
                break;
            }
        }
        return null;
    }

    public ValueTask UnbindAsync(CancellationToken ct = default)
    {
        _server.Dispose();
        return ValueTask.CompletedTask;
    }

    public ValueTask DisposeAsync()
    {
        if (!_disposed)
        {
            _disposed = true;
            _server.Dispose();
        }
        return ValueTask.CompletedTask;
    }
}
