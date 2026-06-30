// Package zo holds the shared glue for the Go interop-matrix programs:
// reading the standard env contract, opening a Ziti context from the
// enrolled identity JSON, and printing the exact RESULT line the harness
// parses.
package zo

import (
	"fmt"
	"os"
	"strings"

	"github.com/openziti/sdk-golang/ziti"
)

// Env is the per-program configuration drawn from the environment, matching
// the cross-language interop contract.
type Env struct {
	IdentityPath string // ZITI_IDENTITY, path to the enrolled identity JSON
	Service      string // ZITI_SERVICE, the Ziti service to bind or dial
	SelfLang     string // SELF_LANG, this program's language code
}

// LoadEnv reads the contract env vars and applies defaults.
func LoadEnv() Env {
	id := os.Getenv("ZITI_IDENTITY")
	if id == "" {
		id = "/ziti/id.json"
	}
	lang := os.Getenv("SELF_LANG")
	if lang == "" {
		lang = "go"
	}
	return Env{
		IdentityPath: id,
		Service:      os.Getenv("ZITI_SERVICE"),
		SelfLang:     lang,
	}
}

// Context loads the enrolled identity JSON and returns an authenticated Ziti
// context. The identity is assumed already enrolled; we never enroll here.
func (e Env) Context() (ziti.Context, error) {
	cfg, err := ziti.NewConfigFromFile(e.IdentityPath)
	if err != nil {
		return nil, fmt.Errorf("load identity %q: %w", e.IdentityPath, err)
	}
	ctx, err := ziti.NewContext(cfg)
	if err != nil {
		return nil, fmt.Errorf("new ziti context: %w", err)
	}
	return ctx, nil
}

// Target is the last dotted segment of the service name (echo.py -> py).
func (e Env) Target() string {
	if e.Service == "" {
		return "?"
	}
	parts := strings.Split(e.Service, ".")
	return parts[len(parts)-1]
}

// ResultOK prints the single success line and signals exit 0.
func ResultOK(app, selfLang, target string, ms int64) {
	fmt.Printf("RESULT ok %s %s->%s %dms\n", app, selfLang, target, ms)
}

// ResultFail prints the single failure line and exits non-zero.
func ResultFail(app, selfLang, target, reason string) {
	// Keep the reason on one line so the harness can parse it.
	reason = strings.ReplaceAll(reason, "\n", " ")
	fmt.Printf("RESULT fail %s %s->%s %s\n", app, selfLang, target, reason)
	os.Exit(1)
}
