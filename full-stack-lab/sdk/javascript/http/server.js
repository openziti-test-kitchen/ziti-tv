// HTTP server over OpenZiti using the Node SDK (@openziti/ziti-sdk-nodejs).
//
// Serves HTTP over a Ziti listener for the service named by ZITI_SERVICE. No TCP
// port is opened: ziti.express() wraps Express so app.listen() binds the overlay
// service instead of a port.
//
//   GET /         -> 200 JSON {"lang":"js","host":<hostname>}
//   GET /healthz  -> 200 "ok"
//
// SDK calls (grounded in lib/express.js + lib/express-listener.js):
//   ziti.init(identityPath) -> Promise
//   ziti.express(express, serviceName) -> wrapped express app
//   app.listen()  (the port argument is ignored; the service name is the bind)

'use strict';

const express = require('express');
const ziti = require('@openziti/ziti-sdk-nodejs');
const os = require('os');
const { getConfig } = require('../common');

async function main() {
  const { identity, service, selfLang } = getConfig();

  await ziti.init(identity);

  const app = ziti.express(express, service);

  app.get('/healthz', (req, res) => {
    res.status(200).type('text/plain').send('ok');
  });

  app.get('/', (req, res) => {
    res.status(200).json({ lang: selfLang, host: os.hostname() });
  });

  // The port arg is ignored by the ziti-wrapped listen(); pass 0 for clarity.
  app.listen(0, () => {
    console.log(`serving HTTP over the overlay on service '${service}'; no TCP port is open`);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
