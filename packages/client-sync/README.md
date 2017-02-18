# Client Sync

This is the mail sync engine that runs within the Nylas Mail client

It is symlinked in as an `internal_package` of Nylas Mail via the `postinstall`
script of the root repo.

## Important Usage Notes:

Since this is symlinked in as an `internal_package` of Nylas Mail, there are a
handulf of considerations when developing in client-sync. Some common gotchas:

- You MAY use `NylasEnv`, `NylasExports` and other injected libraries in the
  Nylas Mail client environment.
- You MAY use any 3rd party library declared in `client-app/package.json`.
  Since this gets added as a plugin of the Nylas Mail client, you'll have
  access to all libraries. This works because the `client-app/node_modules` was
  added to the global require paths. That lets us access client-app plugins
  without being a file directory decendent of client-app (client-sync is now a
  sibling of client-app)
- You may NOT add "dependencies" to the `client-sync/package.json`. If you need
  a 3rd party library, add it to the main `client-app/package.json`. All Nylas
  Mail plugins (those inside of `internal_packages`), may no longer declare
  their own dependencies.
- You should be aggressive at moving generic mail methods to `isomorphic-core`.
  We may eventually want to make large chunks of client-sync work in a cloud
  environment as well.
