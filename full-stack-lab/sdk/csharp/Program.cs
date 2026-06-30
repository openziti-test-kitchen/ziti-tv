using ZoSdk;

// Entrypoint: APP (echo|http) ROLE (server|client)
// Env: ZITI_IDENTITY, ZITI_SERVICE, SELF_LANG=cs

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: zosdk <echo|http> <server|client>");
    return 1;
}

string app  = args[0].ToLowerInvariant();
string role = args[1].ToLowerInvariant();

return (app, role) switch
{
    ("echo", "server") => RunSync(EchoServer.Run),
    ("echo", "client") => EchoClient.Run(),
    ("http", "server") => RunAsyncVoid(() => HttpServer.Run()),
    ("http", "client") => RunAsync(() => ZitiHttpClient.Run()),
    _                  => Fail($"unknown app/role: {app}/{role}"),
};

static int RunSync(Action action)
{
    action();
    return 0;
}

static int RunAsync(Func<Task<int>> fn) => fn().GetAwaiter().GetResult();
static int RunAsyncVoid(Func<Task> fn) { fn().GetAwaiter().GetResult(); return 0; }
static int Fail(string msg) { Console.Error.WriteLine(msg); return 1; }
