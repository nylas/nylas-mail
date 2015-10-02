![N1 Logo](https://edgehill.s3.amazonaws.com/static/N1.png)

**An extensible, open-source mail client built on the modern web.**

N1 is a foundation to build new email experiences. It's built on
[Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).

We are currently in an invite-only beta. Sign up [here](https://invite.nylas.com)
to get early access. Star this repository to get even earlier access.

# Getting Started Building Extensions

Everything in N1 is an extension. Building your own is easy.

1. Sign up [here](https://invite.nylas.com) to request an early access token
1. Use your token to download N1
1. Follow the getting started guides here to write your first extension in 5 minutes

# Contributing to N1 Core

You currently need an early access token to get setup on N1. Sign up [here](https://invite.nylas.com) to request one.

Once you have a token:

  ```
  git clone https://github.com/nylas/N1.git
  cd N1
  script/bootstrap
  ./N1.sh --dev
  ```

Our early access tokens are designed control access to our production mail sync
engine while we roll out N1. However, the sync engine is [open
source](https://github.com/nylas/sync-engine) and you can set it up yourself to
begin using N1 immediately. Follow instructions on the [sync engine](https://github.com/nylas/sync-engine) repository.
