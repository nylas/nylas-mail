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

Read the [getting started guides](http://nylas.github.io/N1/docs/).

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
