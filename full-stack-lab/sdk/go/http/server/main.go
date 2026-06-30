// HTTP server over OpenZiti. Serves HTTP on a Ziti listener bound to
// ZITI_SERVICE. GET / returns 200 JSON {"lang":"go","host":<hostname>};
// GET /healthz returns 200 "ok". No TCP port is opened.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/netfoundry/zo-sdk-go/internal/zo"
)

func main() {
	env := zo.LoadEnv()
	if env.Service == "" {
		log.Fatal("ZITI_SERVICE is not set")
	}

	ctx, err := env.Context()
	if err != nil {
		log.Fatalf("ziti: %v", err)
	}
	defer ctx.Close()

	listener, err := ctx.Listen(env.Service)
	if err != nil {
		log.Fatalf("bind service %q: %v", env.Service, err)
	}
	defer listener.Close()

	host, _ := os.Hostname()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_ = json.NewEncoder(w).Encode(map[string]string{
			"lang": env.SelfLang,
			"host": host,
		})
	})

	log.Printf("http server hosting %q over the overlay (lang=%s)", env.Service, env.SelfLang)

	// http.Serve drives the Ziti net.Listener exactly like a TCP one.
	if err := http.Serve(listener, mux); err != nil {
		log.Fatalf("http serve: %v", err)
	}
}
