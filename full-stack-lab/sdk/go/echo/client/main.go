// Echo client over OpenZiti. Dials ZITI_SERVICE, sends "ping from go\n",
// reads one line back, and prints the standard RESULT line. OK when the reply
// matches what was sent.
package main

import (
	"bufio"
	"log"
	"time"

	"github.com/netfoundry/zo-sdk-go/internal/zo"
)

const app = "echo"

func main() {
	env := zo.LoadEnv()
	if env.Service == "" {
		log.Fatal("ZITI_SERVICE is not set")
	}
	target := env.Target()

	ctx, err := env.Context()
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "ziti-context: "+err.Error())
	}
	defer ctx.Close()

	start := time.Now()

	conn, err := ctx.Dial(env.Service)
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "dial: "+err.Error())
	}
	defer conn.Close()

	const msg = "ping from go\n"
	if _, err := conn.Write([]byte(msg)); err != nil {
		zo.ResultFail(app, env.SelfLang, target, "write: "+err.Error())
	}

	reply, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil {
		zo.ResultFail(app, env.SelfLang, target, "read: "+err.Error())
	}

	if reply != msg {
		zo.ResultFail(app, env.SelfLang, target, "mismatch")
	}

	zo.ResultOK(app, env.SelfLang, target, time.Since(start).Milliseconds())
}
