using System.Runtime.InteropServices;
using OpenZiti;

namespace ZoSdk;

internal static class Env
{
    public static string IdentityFile =>
        Environment.GetEnvironmentVariable("ZITI_IDENTITY") ?? "/ziti/id.json";

    public static string ServiceName =>
        Environment.GetEnvironmentVariable("ZITI_SERVICE")
            ?? throw new InvalidOperationException("ZITI_SERVICE is not set");

    /// <summary>Last dotted segment of the service name (e.g. "echo.go" -> "go").</summary>
    public static string Target(string serviceName)
    {
        int dot = serviceName.LastIndexOf('.');
        return dot >= 0 ? serviceName[(dot + 1)..] : serviceName;
    }

    /// <summary>
    /// Load a ZitiContext from an identity file path.
    ///
    /// nAPI.Ziti_load_context declares identity as byte[], which .NET marshals without a null
    /// terminator. The native C function receives a non-null-terminated char* so fopen fails
    /// and returns ZITI_CONFIG_NOT_FOUND (-1). Fix: use our own P/Invoke with
    /// [MarshalAs(UnmanagedType.LPStr)] string, which appends the null byte automatically.
    /// </summary>
    public static ZitiContext LoadContext(string identityFile)
    {
        ZitiNative.Ziti_lib_init();

        nint handle = 0;
        int rc = ZitiNative.Ziti_load_context_with_timeout(out handle, identityFile, 120_000);
        if (rc != 0)
        {
            nint errPtr = ZitiNative.ziti_errorstr(rc);
            string errMsg = Marshal.PtrToStringAnsi(errPtr) ?? $"error {rc}";
            throw new InvalidOperationException($"Ziti_load_context failed ({rc}): {errMsg}");
        }

        // Use the internal IntPtr ctor - sets NativeContext = ptr directly.
        var ctx = (ZitiContext)Activator.CreateInstance(
            typeof(ZitiContext),
            System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic,
            null,
            new object[] { handle },
            null)!;

        return ctx;
    }

    private static class ZitiNative
    {
        private const string Lib = "ziti4dotnet";

        [DllImport(Lib, EntryPoint = "Ziti_lib_init", CallingConvention = CallingConvention.Cdecl)]
        public static extern void Ziti_lib_init();

        [DllImport(Lib, EntryPoint = "Ziti_load_context_with_timeout",
                   CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern int Ziti_load_context_with_timeout(out nint h,
            [MarshalAs(UnmanagedType.LPStr)] string identity,
            int timeout_ms);

        [DllImport(Lib, EntryPoint = "ziti_errorstr", CallingConvention = CallingConvention.Cdecl)]
        public static extern nint ziti_errorstr(int err);
    }
}
