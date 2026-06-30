using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Text;
using OpenZiti;

namespace ZoSdk;

/// <summary>
/// Dials ZITI_SERVICE, sends "ping from cs\n", reads one line back, asserts it matches.
/// Prints exactly one RESULT line and exits 0 on success, non-zero on failure.
/// </summary>
public static class EchoClient
{
    public static int Run()
    {
        string identityFile = Env.IdentityFile;
        string serviceName  = Env.ServiceName;
        string target       = Env.Target(serviceName);

        var sw = Stopwatch.StartNew();
        try
        {
            var ctx    = Env.LoadContext(identityFile);
            var socket = new ZitiSocket(SocketType.Stream);
            API.Connect(socket, ctx, serviceName, "");

            using var ns = socket.ToNetworkStream();
            using var r  = new StreamReader(ns, Encoding.UTF8, leaveOpen: true);
            using var w  = new StreamWriter(ns, Encoding.UTF8, leaveOpen: true) { AutoFlush = true };

            const string ping = "ping from cs";
            w.WriteLine(ping);

            string? reply = r.ReadLine();
            sw.Stop();

            if (reply == ping)
            {
                Console.WriteLine($"RESULT ok echo cs->{target} {sw.ElapsedMilliseconds}ms");
                return 0;
            }

            Console.WriteLine($"RESULT fail echo cs->{target} unexpected-reply:{reply ?? "<null>"}");
            return 1;
        }
        catch (Exception ex)
        {
            sw.Stop();
            string reason = ex.Message.Replace(' ', '-');
            Console.WriteLine($"RESULT fail echo cs->{target} {reason}");
            return 2;
        }
    }
}
