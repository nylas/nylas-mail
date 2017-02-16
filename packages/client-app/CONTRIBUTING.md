# Filing an Issue

Thanks for checking out N1! If you have a feature request, be sure to check out the [open source roadmap](http://trello.com/b/hxsqB6vx/n1-open-source-roadmap). If someone has already requested
the feature you have in mind, you can upvote the card on Trello—to keep things organized, we
often close feature requests on GitHub after creating Trello cards.

If you've found a bug, try searching for similars issue before filing a new one. Please include
the version of N1 you're using, the platform you're using (Mac / Windows / Linux), and the
type of email account. (Gmail, Outlook 365, etc.)

# Contributing to N1

The hosted sync engine allows us to control adoption of N1 and maintain a great
experience for our users. However, the sync engine is
[open source](https://github.com/nylas/sync-engine) and you can set it
up yourself to begin using N1 immediately. Follow instructions on the [sync
engine](https://github.com/nylas/sync-engine) repository.

### Getting Started

Before you get started, make sure you've installed the following dependencies.
N1's build scripts and tooling use modern JavaScript features and require:

 - Node 6.0 or above with npm3
 - python 2.7

Linux users should make sure they've installed all the packages listed at
https://github.com/nylas/nylas-mail/blob/master/.travis.yml#L10. Linux users on
Debian 8 and Ubuntu 15.04 onward must also install libgcrypt11 and gnome-keyring.

Next, clone and build N1 from source:

    git clone https://github.com/nylas/nylas-mail.git
    cd nylas-mail
    script/bootstrap

Read the [getting started guides](https://nylas.github.io/N1/getting-started/).

**Building Nylas on Windows? See the [Windows instructions.](https://github.com/nylas/nylas-mail/blob/master/docs/Windows.md)**

### Running N1

    npm start

### Testing N1

    npm test

This will run the full suite of automated unit tests. We use [Jasmine 1.3](http://jasmine.github.io/1.3/introduction.html).

It runs all tests inside of the `/spec` folder and all tests inside of
`/internal_packages/**/spec`

You may skip certain tests (temporarily) with `xit` and `xdescribe`, or focus on only certain tests with `fit` and `fdescribe`.

### Linting N1

N1 lints clean against eslint, coffeelint, csslint, lesslint, and our own internal
tool, nylaslint. To run the linters, just run `npm run lint`.

### Creating binaries

Once you've checked out N1 and run `script/bootstrap`, you can create a packaged
version of the application by running `script/build`. Note that the builds
available at [https://nylas.com/N1](https://nylas.com/N1) include licensed
fonts, sounds, and other improvements. If you're just looking to run N1, you
should download it there!


# Pull requests

We require all authors sign our [Contributor License
Agreement](https://www.nylas.com/cla.html) before pull requests (even
minor ones) can be accepted. (It's similar to other projects, like NodeJS
Meteor, or React). I'm really sorry, but Legal made us do it.

### Commit Format

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

# Running Against Open Source Sync Engine

See [Configuration](https://github.com/nylas/nylas-mail/blob/master/CONFIGURATION.md)
