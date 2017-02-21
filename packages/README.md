# Monorepo Packages

Each folder here is designed to act as its own repository. For development
convenience, they are all included here in one monorepo. This allows us to grep
across multiple codebases, not use submodules, and keep a unified commit
history.

We use [Lerna](https://github.com/lerna/lerna) to manage the monorepo and tie
them all together with the main `nylas-mail-all/scripts/postinstall.es6` script,
which in turn, calls `lerna bootstrap`
