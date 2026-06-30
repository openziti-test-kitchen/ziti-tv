// HTTP client over OpenZiti. Performs an HTTP GET / over a Ziti connection to
// ZITI_SERVICE by wiring an http.Transport whose DialContext dials the Ziti
// service. OK when status is 200 and the body parses as JSON.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/netfoundry/zo-sdk-go/internal/zo"

	"github.com/openziti/sdk-golang/ziti"
)

const app = "http"

// zitiDialContext routes the HTTP transport's connections over the overlay.
// The host portion of the dialed address is the Ziti service name.
type zitiDialContext struct {
	ctx ziti.Context
}

func (d *zitiDialContext) Dial(_ context.Context, _ string, addr string) (net.Conn, error) {
	service := strings.Split(addr, ":")[0]
	return d.ctx.Dial(service)
}

func main() {
	env := zo.LoadEnv()
	if env.Service == "" {
		log.Fatal("ZITI_SERVICE is not set")
	}
	target := env.Target()

	zctx, err := env.Context()
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "ziti-context: "+err.Error())
	}
	defer zctx.Close()

	dc := &zitiDialContext{ctx: zctx}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.DialContext = dc.Dial
	client := &http.Client{Transport: transport, Timeout: 30 * time.Second}

	// The URL host is the Ziti service name; the scheme is plain http because
	// the overlay provides the encrypted transport.
	url := fmt.Sprintf("http://%s/", env.Service)

	start := time.Now()

	resp, err := client.Get(url)
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "get: "+err.Error())
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "read: "+err.Error())
	}

	if resp.StatusCode != http.StatusOK {
		zo.ResultFail(app, env.SelfLang, target, fmt.Sprintf("status %d", resp.StatusCode))
	}

	var parsed map[string]interface{}
	if err := json.Unmarshal(body, &parsed); err != nil {
		zo.ResultFail(app, env.SelfLang, target, "bad-json: "+err.Error())
	}

	zo.ResultOK(app, env.SelfLang, target, time.Since(start).Milliseconds())
}
