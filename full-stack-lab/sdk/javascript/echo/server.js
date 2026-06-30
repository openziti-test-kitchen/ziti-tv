// Echo server over OpenZiti using the Node SDK (@openziti/ziti-sdk-nodejs).
//
// App-embedded zero trust: binds (hosts) the Ziti service named by ZITI_SERVICE
// and echoes back whatever each client sends. No TCP listener, no open port.
//
// SDK calls (grounded in the package's lib/*.js and native src/ziti_listen.c):
//   ziti.init(identityPath) -> Promise
//   ziti.listen(serviceName, jsArbData, on_listen, on_listen_client,
//               on_client_connect, on_client_data)
//   ziti.write(conn, buf, cb)
// The native layer delivers per-client callbacks an object shaped:
//   on_client_connect: { client, status, js_arb_data }
//   on_client_data:    { client, app_data (Buffer), js_arb_data }

'use strict';

const ziti = require('@openziti/ziti-sdk-nodejs');
const { getConfig } = require('../common');

async function main() {
  const { identity, service } = getConfig();

  await ziti.init(identity);

  // jsArbData is an opaque token the SDK echoes back on every client callback.
  const jsArbData = 1;

  ziti.listen(
    service,
    jsArbData,
    // on_listen: listener is up (status >= 0 means success)
    (status) => {
      if (typeof status === 'number' && status < 0) {
        console.error(`failed to bind service '${service}': status ${status}`);
        process.exit(1);
      }
      console.log(`hosting service '${service}' over the overlay; no TCP port is open`);
    },
    // on_listen_client: a client session is being established
    () => {},
    // on_client_connect: client connected
    (obj) => {
      if (obj && typeof obj.status === 'number' && obj.status < 0) {
        console.error(`client connect error: status ${obj.status}`);
      }
    },
    // on_client_data: echo the bytes straight back to the same client conn
    (obj) => {
      if (!obj || obj.app_data == null) {
        return; // client closed / no data
      }
      ziti.write(obj.client, obj.app_data, (writeStatus) => {
        if (typeof writeStatus === 'number' && writeStatus < 0) {
          console.error(`echo write failed: status ${writeStatus}`);
        }
      });
    }
  );

  // Host forever.
  await new Promise(() => {});
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
