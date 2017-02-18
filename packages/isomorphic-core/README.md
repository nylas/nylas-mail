# Isomorphic Core

Isomorphic refers to javascript that can be run on both the client and the
server.

This is shared code for mail and utilities that is designed to run both on
deployed cloud servers and from within the Nylas Mail client.

Use through a regular import: `import iso-core from 'isomorphic-core'`

It is required as a dependency in the package.json of other modules.

This library isn't on the npm registry, but works as a dependency thanks to
`lerna bootstrap`

See index.js for what gets explicitly exported by this library.

## Important Usage Notes:

Since this code runs in both the client and the server, you must be careful
with what libraries you use. Some common gotchas:

- You can't use `NylasEnv` or `NylasExports`. These are injected only in the
  client.
- If you require a 3rd party library, it must be added to the "dependencies" of
  isomorphic-core's `package.json`
- You may use modern javascript syntax. Both the client and server get compiled
  with the same .babelrc setting
