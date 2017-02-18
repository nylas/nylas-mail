# Client Private Plugins

This contains proprietary Nylas plugins and other extensions to Nylas Mail that
we do not want appearing in the open source mirror of client-app.

It is symlinked in as an `internal_package` of Nylas Mail via the `postinstall`
script of the root repo.

## Important Usage Notes:

Since plugins here are symlinked into `internal_package` of Nylas Mail, there
are a handulf of considerations when developing in client-private-plugins. Some
common gotchas:

- You MAY use `NylasEnv`, `NylasExports` and other injected libraries in the
  Nylas Mail client environment.
- You MAY use any 3rd party library declared in `client-app/package.json`.
  Since this gets added as a plugin of the Nylas Mail client, you'll have
  access to all libraries. This works because the `client-app/node_modules` was
  added to the global require paths. That lets us access client-app plugins
  without being a file directory decendent of client-app
  (client-private-plugins is now a sibling of client-app)
- You may NOT add "dependencies" to the `client-private-plugins/package.json`.
  If you need a 3rd party library, add it to the main
  `client-app/package.json`. All Nylas Mail plugins (those inside of
  `internal_packages`), may no longer declare their own dependencies.
