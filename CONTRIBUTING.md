# Contributing to N1 Core

Thank you for contributing!!

N1 core is the foundation our community uses to build email extensions with the
modern web.

You currently need an early invitation code to get setup on N1. Sign up
[here](https://invite.nylas.com) to request one. Drop us a line saying you'd
like to contribute to N1 core and we'll get you set up immediately.

# Getting Started

Once you have an invitation code:

    git clone https://github.com/nylas/N1.git
    cd N1
    script/bootstrap

Read the [getting started guides](http://nylas.com/N1/docs/).

See [Windows instructions here](https://github.com/nylas/N1/blob/master/docs/Windows.md)

Linux users on Debian 8 and Ubuntu 15.04 onward must also install libgcrypt11, which Electron depends on. 

# Running N1 Core

    ./N1.sh --dev

Once the app boots, you'll be prompted to enter your early invitation code and
email credentials.

Our early invitation codes are designed control access to our production mail sync
engine while we roll out N1. However, the sync engine is [open
source](https://github.com/nylas/sync-engine) and you can set it up yourself to
begin using N1 immediately. Follow instructions on the [sync
engine](https://github.com/nylas/sync-engine) repository.

# Testing N1 Core

    ./N1.sh --test

This will run the full suite of automated unit tests. We use [Jasmine 1.3](http://jasmine.github.io/1.3/introduction.html).

It runs all tests inside of the `/spec` folder and all tests inside of
`/internal_packages/**/spec`

# Pull requests

We require all authors sign our [Contributor License
Agreement](https://www.nylas.com/cla.html) before pull requests (even
minor ones) can be accepted. (It's similar to other projects, like NodeJS
Meteor, or React). I'm really sorry, but Legal made us do it.

## Commit Format

We decided to not impose super strict commit guidelines on the community.

We're trusting you to be thoughtful, responsible, committers.

We do have a few heuristics:

- Keep commits fairly isolated. Don't jam lots of different functionality
  in 1 squashed commit. `git bisect` and `git cherry-pick` should still be
  reasonable things to do.
- Keep commits fairly significant. DO `squash` all those little file
  changes and "fixmes". Don't make it difficult to browse our history.
  Play the balance between this idea and the last point. If a commit
  doesn't deserve your time to write a long thoughtful message about, then
  squash it.
- Be hyper-descriptive in your commit messages. I care less about what
  you did (I can read the code), **I want to know WHY you did it**. Put
  that in the commit body (not the subject). Itemize the major semantic
  changes that happened.
- Read "[How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/)" if you haven't already (but don't be too prescriptivist about it!)

# Building

Once you've checked out N1 and run `script/bootstrap`, you can create a packaged
version of the application by running `script/build`. Note that the builds
available at [https://nylas.com/N1](https://nylas.com/N1) include licensed
fonts, sounds, and other improvements. If you're just looking to run N1, you
should download it there!

# Running Against Open Source Sync Engine

N1 needs to fetch mail from a running instance of the [Nylas Sync
Engine](https://github.com/nylas/sync-engine). The Sync Engine is what
abstracts away IMAP, POP, and SMTP to serve your email on any provider
through a modern, RESTful API.

By default the N1 source points to our hosted version of the sync-engine;
however, the Sync Engine is open source and you can run it yourself.

1. Install the Nylas Sync Engine in a Vagrant virtual machine by following the
  [installation and setup](https://github.com/nylas/sync-engine#installation-and-setup)
  instructions.

2. Once you've installed the sync engine, add accounts by running the inbox-auth
   script. For Gmail accounts, the syntax is simple: `bin/inbox-auth you@gmail.com`

3. Start the sync engine by running `bin/inbox-start` and the API via `bin/inbox-api`.

4. After you've linked accounts to the Sync Engine, open or create a file at
   `~/.nylas/config.cson`. This is the config file that N1 reads at launch.

   Replace `env: "production"` with `env: "local"` at the top level of the config.
   This tells N1 to look at `localhost:5555` for the sync engine. If you've deployed
   the sync engine elsewhere, you'll need to edit `nylas-api.coffee`.

   Copy the JSON array of accounts returned from the Sync Engine's `/accounts`
   endpoint (ex. `http://localhost:5555/accounts`) into the config file at the
   path `*.nylas.accounts`.

   N1 will look for access tokens for these accounts under `*.nylas.accountTokens`,
   but the open source version of the sync engine does not provide access tokens.
   When you make requests to the open source API, you provide an account
   ID in the HTTP Basic Auth username field instead of an account token.

   For each account you've created, add an entry to `*.nylas.accountTokens`
   with the account ID as both the key and value.

   The final `config.cson` file should look something like this:

        "*":
          env: "local"
          nylas:
            accounts: [
              {
                server_id: "{ACCOUNT_ID_1}"
                object: "account"
                account_id: "{ACCOUNT_ID_1}"
                name: "{YOUR NAME}"
                provider: "{PROVIDER_NAME}"
                email_address: "{YOUR_EMAIL_ADDRESS}"
                organization_unit: "{folder or label}"
                id: "{ACCOUNT_ID_1}"
              }
              {
                server_id: "{ACCOUNT_ID_2}"
                object: "account"
                account_id: "{ACCOUNT_ID_2}"
                name: "{YOUR_NAME}"
                provider: "{PROVIDER_NAME}"
                email_address: "{YOUR_EMAIL_ADDRESS}"
                organization_unit: "{folder or label}"
                id: "{ACCOUNT_ID_2}"
              }
            ]
            accountTokens:
              {ACCOUNT_ID_1}: "{ACCOUNT_ID_1}"
              {ACCOUNT_ID_2}: "{ACCOUNT_ID_2}"

Note: `{ACCOUNT_ID_1}` refers to the database ID of the `Account` object
you create when setting up the Sync Engine. The JSON above should match
fairly closely with the Sync Engine `Account` object.
