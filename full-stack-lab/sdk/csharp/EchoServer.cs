using System.IO;
using System.Net.Sockets;
using OpenZiti;

namespace ZoSdk;

/// <summary>
/// Binds ZITI_SERVICE and echoes every byte received back to the sender, forever.
/// </summary>
public static class EchoServer
{
    public static void Run()
    {
        string identityFile = Env.IdentityFile;
        string serviceName  = Env.ServiceName;

        Console.Error.WriteLine($"[echo-server] identity={identityFile} service={serviceName}");

        var ctx    = Env.LoadContext(identityFile);
        var server = new ZitiSocket(SocketType.Stream);

        API.Bind(server, ctx, serviceName, "");
        API.Listen(server, 32);

        Console.Error.WriteLine($"[echo-server] listening on service '{serviceName}'");

        while (true)
        {
            ZitiSocket client = API.Accept(server, out string caller);
            Console.Error.WriteLine($"[echo-server] accepted from {caller}");
            // Handle each connection on a thread-pool thread so the accept loop keeps going.
            _ = Task.Run(() => HandleClient(client, caller));
        }
    }

    private static void HandleClient(ZitiSocket socket, string caller)
    {
        try
        {
            using var ns  = socket.ToNetworkStream();
            var buf       = new byte[4096];
            int n;
            while ((n = ns.Read(buf, 0, buf.Length)) > 0)
            {
                ns.Write(buf, 0, n);
            }
            Console.Error.WriteLine($"[echo-server] {caller} disconnected");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[echo-server] error from {caller}: {ex.Message}");
        }
        finally
        {
            socket.Dispose();
        }
    }
}
