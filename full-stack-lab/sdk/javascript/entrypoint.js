// Single entrypoint for the zo-sdk-js image.
//
// Usage: node entrypoint.js <APP> <ROLE>
//   APP  = echo | http
//   ROLE = server | client
//
// Dispatches to the matching program. Env (ZITI_IDENTITY, ZITI_SERVICE,
// SELF_LANG) is read by each program via common.js.

'use strict';

const path = require('path');

const APPS = new Set(['echo', 'http']);
const ROLES = new Set(['server', 'client']);

const app = process.argv[2];
const role = process.argv[3];

if (!APPS.has(app) || !ROLES.has(role)) {
  console.error('usage: node entrypoint.js <echo|http> <server|client>');
  process.exit(2);
}

require(path.join(__dirname, app, `${role}.js`));
