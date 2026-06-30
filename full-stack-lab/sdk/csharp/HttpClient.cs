using System.Diagnostics;
using System.Net.Http;
using System.Net.Sockets;
using System.Text.Json;
using OpenZiti;

namespace ZoSdk;

/// <summary>
/// HTTP GET / over Ziti for ZITI_SERVICE. OK if 200 and body has "lang" key.
/// Prints exactly one RESULT line and exits 0 on success, non-zero on failure.
/// </summary>
public static class ZitiHttpClient
{
    public static async Task<int> Run()
    {
        string identityFile = Env.IdentityFile;
        string serviceName  = Env.ServiceName;
        string target       = Env.Target(serviceName);

        var sw = Stopwatch.StartNew();
        try
        {
            var ctx     = Env.LoadContext(identityFile);
            var handler = ctx.NewZitiSocketHandler(serviceName);

            using var http = new HttpClient(handler)
            {
                Timeout = TimeSpan.FromSeconds(30),
                BaseAddress = new Uri($"http://{serviceName}/"),
            };

            var response = await http.GetAsync("/");
            sw.Stop();

            if (!response.IsSuccessStatusCode)
            {
                Console.WriteLine(
                    $"RESULT fail http cs->{target} http-{(int)response.StatusCode}");
                return 1;
            }

            string body = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(body);
            if (!doc.RootElement.TryGetProperty("lang", out _))
            {
                Console.WriteLine($"RESULT fail http cs->{target} missing-lang-field");
                return 1;
            }

            Console.WriteLine($"RESULT ok http cs->{target} {sw.ElapsedMilliseconds}ms");
            return 0;
        }
        catch (Exception ex)
        {
            sw.Stop();
            string reason = ex.Message.Replace(' ', '-');
            Console.WriteLine($"RESULT fail http cs->{target} {reason}");
            return 2;
        }
    }
}
