// Shared helpers for the JS interop programs.
//
// Every client prints EXACTLY one line and sets the exit code:
//   RESULT ok   <APP> js-><TARGET> <ms>ms
//   RESULT fail <APP> js-><TARGET> <reason>
//
// TARGET is the last dotted segment of ZITI_SERVICE (e.g. "echo.go" -> "go").

'use strict';

function getConfig() {
  const identity = process.env.ZITI_IDENTITY || '/ziti/id.json';
  const service = process.env.ZITI_SERVICE;
  const selfLang = process.env.SELF_LANG || 'js';
  if (!service) {
    console.error('ZITI_SERVICE is not set; set it to the Ziti service name to bind/dial');
    process.exit(2);
  }
  return { identity, service, selfLang };
}

// TARGET = last dotted segment of the service name.
function target(service) {
  const parts = service.split('.');
  return parts[parts.length - 1];
}

function resultOk(app, tgt, ms) {
  process.stdout.write(`RESULT ok ${app} js->${tgt} ${ms}ms\n`);
  process.exit(0);
}

function resultFail(app, tgt, reason) {
  const clean = String(reason).replace(/\s+/g, ' ').trim();
  process.stdout.write(`RESULT fail ${app} js->${tgt} ${clean}\n`);
  process.exit(1);
}

module.exports = { getConfig, target, resultOk, resultFail };
