![N1 Logo](https://edgehill.s3.amazonaws.com/static/N1.png)

![N1 Screenshot](http://nylas.com/N1/images/1-1-initial-outlook-base.png)

**N1 is an open-source mail client built on the modern web with [Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).** It is designed to be extensible, so it's easy to create new experiences and workflows around email. N1 is built on the Nylas Sync Engine which is also [open source free software](https://github.com/nylas/sync-engine).

[![Build Status](https://travis-ci.org/nylas/N1.svg?branch=master)](https://travis-ci.org/nylas/N1)
[![Slack Invite Button](http://slack-invite.nylas.com/badge.svg)](http://slack-invite.nylas.com)

# Download N1

You can download compiled versions of N1 for Windows, Mac OS X, and Linux (.deb) from [https://nylas.com/N1](https://nylas.com/N1). You can also build and run N1 on Fedora. A Fedora distribution is coming soon!

# Build A Plugin

Plugins lie at the heart of N1 and give it its powerful features. Building your own plugins allows you to integrate the app with other tools, experiment with new workflows, and more. Follow the [Getting Started guide](http://nylas.com/N1/getting-started/) to write your first plugin in 5 minutes.

If you would like to run the N1 source and contribute, check out our [contributing
guide](https://github.com/nylas/N1/blob/master/CONTRIBUTING.md).

# Plugin List
We're working on building a plugin index that makes it super easy to add them to N1. For now, check out the list below! (Feel free to submit a PR if you build a plugin and want it featured here.)

##### Themes
- [Dark](https://github.com/nylas/N1/tree/master/internal_packages/ui-dark) -- ([tutorial here](https://github.com/nylas/N1/issues/74))
- [Taiga](http://noahbuscher.github.io/N1-Taiga/) -- Mailbox-inspired light theme
- [Predawn](https://github.com/adambmedia/N1-Predawn)
- [ElementaryOS](https://github.com/edipox/elementary-nylas)
- [Ubuntu](https://github.com/ahmedlhanafy/Ubuntu-Ui-Theme-for-Nylas-N1)
- [Material](https://github.com/equinusocio/N1-Material) ([preview](https://twitter.com/MattiaAstorino/status/683348095770456064))
- [Ido](https://github.com/edipox/n1-ido) -- Polymail-inspired theme
- [Wattenberger](https://github.com/Wattenberger/Nylas-N1-theme)
- [Solarized Dark](https://github.com/NSHenry/N1-Solarized-Dark)

##### Composer
- [Translate](https://github.com/nylas/N1/tree/master/internal_packages/composer-translate) -- Works with 10 languages
- [QuickSchedule](https://github.com/nylas/N1/tree/master/internal_packages/quick-schedule) -- Quickly schedule a meeting with someone
- [Templates](https://github.com/nylas/N1/tree/master/internal_packages/composer-templates) -- Also sometimes known as "canned responses"
- [Jiffy](http://noahbuscher.github.io/N1-Jiffy/) -- Insert animated Gifs
- In Development: [PGP Encryption](https://github.com/mbilker/email-pgp)

##### Sidebar
- [GitHub info in Sidebar](https://github.com/nylas/N1/tree/master/internal_packages/github-contact-card)
- [Weather](https://github.com/jackiehluo/n1-weather)
- [Todoist](https://github.com/anopensourceguy/TodoistN1)

##### Navbar
- [Open GitHub Issues](https://github.com/nylas/N1/tree/master/internal_packages/message-view-on-github)

##### Threadlist
- [Personal-level indicators](https://github.com/nylas/N1/tree/master/internal_packages/personal-level-indicators)
- [Unsubscribe button](https://github.com/colinking/n1-unsubscribe)

##### Message View
- [Phishing Detection](https://github.com/nylas/N1/tree/master/internal_packages/phishing-detection)
- [Squirt Speed Reader](https://github.com/HarleyKwyn/squirt-reader-N1-plugin/)

# Running Locally
By default the N1 source points to our hosted version of the Nylas Sync Engine; however, the Sync Engine is open source and you can [run it yourself](https://github.com/nylas/N1/blob/master/CONTRIBUTING.md#running-against-open-source-sync-engine).

# Feature Requests / Plugin Ideas

Have an idea for a package, or a feature you'd love to see in N1? Check out our
[public Trello board](https://trello.com/b/hxsqB6vx/n1-open-source-roadmap)
to contribute your thoughts and vote on existing ideas.
