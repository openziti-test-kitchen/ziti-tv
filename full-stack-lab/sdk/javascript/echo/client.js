// Echo client over OpenZiti using the Node SDK (@openziti/ziti-sdk-nodejs).
//
// Dials the Ziti service named by ZITI_SERVICE, sends "ping from js\n", reads a
// line back, and prints the single RESULT line. No tunneler, no host:port.
//
// SDK calls (grounded in the package's lib/dial.js, lib/write.js, lib/close.js):
//   ziti.init(identityPath) -> Promise
//   ziti.dial(serviceName, isWebSocket, onConnect(conn), onData(buf))
//   ziti.write(conn, buf, cb)
//   ziti.close(conn)

'use strict';

const ziti = require('@openziti/ziti-sdk-nodejs');
const { getConfig, target, resultOk, resultFail } = require('../common');

const APP = 'echo';
const MESSAGE = 'ping from js\n';
const TIMEOUT_MS = 10000;

async function main() {
  const { identity, service } = getConfig();
  const tgt = target(service);

  await ziti.init(identity);

  const start = Date.now();
  let settled = false;
  let acc = '';

  const timer = setTimeout(() => {
    if (!settled) {
      settled = true;
      resultFail(APP, tgt, 'timeout waiting for echo reply');
    }
  }, TIMEOUT_MS);

  // onConnect receives the connection handle; onData receives a Buffer.
  ziti.dial(
    service,
    false, // isWebSocket: false -> raw byte stream
    (conn) => {
      ziti.write(conn, Buffer.from(MESSAGE), (status) => {
        if (typeof status === 'number' && status < 0 && !settled) {
          settled = true;
          clearTimeout(timer);
          resultFail(APP, tgt, `write failed status ${status}`);
        }
      });
      // Stash the conn so onData can close it.
      main._conn = conn;
    },
    (data) => {
      if (settled) return;
      acc += data.toString('utf8');
      const nl = acc.indexOf('\n');
      if (nl === -1) return; // wait for a full line

      settled = true;
      clearTimeout(timer);
      const line = acc.slice(0, nl + 1);
      try { ziti.close(main._conn); } catch (e) { /* ignore */ }

      if (line === MESSAGE) {
        resultOk(APP, tgt, Date.now() - start);
      } else {
        resultFail(APP, tgt, `mismatch want ${JSON.stringify(MESSAGE)} got ${JSON.stringify(line)}`);
      }
    }
  );
}

main().catch((err) => {
  resultFail(APP, target(process.env.ZITI_SERVICE || 'unknown'), err.message || String(err));
});
