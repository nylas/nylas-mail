# Filters package for N1

<img src="https://raw.githubusercontent.com/nylas/N1/master/examples/N1-Filters/filters-screencap.png">

#### Install this plugin

1. Download and run N1

2. From the menu, select `Developer > Install a Package Manually...`
   The dialog will default to this examples directory. Just choose the
   package to install it!

   > When you install packages, they're moved to `~/.nylas/packages`,
   > and N1 runs `apm install` on the command line to fetch dependencies
   > listed in the package's `package.json`

#### Who?

The source is annotated for people who are familiar with React, but not familiar with APIs from either Atom or N1.

As such, we will not annotate any code that is specific for React, but we'll annotate code for everything else.

#### Why?

There's no native way to automate mail filtering in N1. This package provides a lightweight interface and implementation of mail filters and mail rules to handle repetitive mail tasks for you.

#### How?

This package works in two steps: managing the filters and applying the filters.

Managing the filters boils down to simple CRUD operations.

Applying the filters boils down to checking each incoming message, checking to see if the message matches any of the requirements for the filters, and, if there's a match, applying the actions on the thread.

Currently, this package supports only simple filter operations. The only criteria it supports are:
- exact match sender email
- exact match recipient email
- substring match with subject & body
- substring absense with subject & body

The only actions this package supports currently are:
- Marking as read
- Applying labels or folders
- Starring
- Deleting
- Archiving (skipping the inbox)

#### Roadmap

Right now, both managing the filters and applying the filters is done client-side.

The immediate objective is to implement an amazing user experience for managing mail filters.

The long-term objective is to remove the client-side implementation of applying filters and move this work to the backend.
