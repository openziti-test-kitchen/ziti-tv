// HTTP client over OpenZiti using the Node SDK (@openziti/ziti-sdk-nodejs).
//
// Performs an HTTP GET / over the Ziti connection for ZITI_SERVICE and prints
// the single RESULT line. OK when status is 200 and the body parses as JSON.
//
// SDK calls (grounded in lib/connect.js + samples/http-get.mjs):
//   ziti.init(identityPath) -> Promise
//   ziti.httpAgent(http) -> an http.Agent that dials via the overlay
//   http.get(url, { agent }, cb)  with url host = the Ziti service name
//
// The service name is used as the URL host; the port is ignored by the agent,
// which resolves the service via the controller.

'use strict';

const http = require('node:http');
const ziti = require('@openziti/ziti-sdk-nodejs');
const { getConfig, target, resultOk, resultFail } = require('../common');

const APP = 'http';
const TIMEOUT_MS = 10000;

async function main() {
  const { identity, service } = getConfig();
  const tgt = target(service);

  await ziti.init(identity);

  const start = Date.now();
  let settled = false;
  const done = (fn) => { if (!settled) { settled = true; fn(); } };

  const agent = ziti.httpAgent(http);
  const url = `http://${service}/`;

  const req = http.get(url, { agent }, (res) => {
    let body = '';
    res.on('data', (chunk) => { body += chunk.toString('utf8'); });
    res.on('end', () => {
      if (res.statusCode !== 200) {
        return done(() => resultFail(APP, tgt, `status ${res.statusCode}`));
      }
      try {
        JSON.parse(body);
      } catch (e) {
        return done(() => resultFail(APP, tgt, `body not JSON: ${e.message}`));
      }
      done(() => resultOk(APP, tgt, Date.now() - start));
    });
  });

  req.setTimeout(TIMEOUT_MS, () => {
    req.destroy();
    done(() => resultFail(APP, tgt, 'timeout waiting for http response'));
  });

  req.on('error', (err) => {
    done(() => resultFail(APP, tgt, err.message || String(err)));
  });
}

main().catch((err) => {
  resultFail(APP, target(process.env.ZITI_SERVICE || 'unknown'), err.message || String(err));
});
