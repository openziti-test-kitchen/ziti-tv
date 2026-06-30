// Echo server over OpenZiti. Binds ZITI_SERVICE on the overlay and echoes
// every byte received on each accepted connection back to the sender. No TCP
// port is opened: connectivity comes entirely from the Ziti overlay.
package main

import (
	"io"
	"log"
	"net"

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

	log.Printf("echo server hosting %q over the overlay (lang=%s)", env.Service, env.SelfLang)

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Printf("accept error: %v", err)
			continue
		}
		go handle(conn)
	}
}

// handle echoes everything received on the connection back to the sender.
func handle(conn net.Conn) {
	defer conn.Close()
	if _, err := io.Copy(conn, conn); err != nil && err != io.EOF {
		log.Printf("echo error: %v", err)
	}
}
