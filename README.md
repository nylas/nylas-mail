![N1 Logo](https://edgehill.s3.amazonaws.com/static/N1.png)

![N1 Screenshot](http://nylas.com/N1/images/1-1-initial-outlook-base.png?feb2016)

**N1 is an open-source mail client built on the modern web with [Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).** It is designed to be extensible, so it's easy to create new experiences and workflows around email. N1 is built on the Nylas Sync Engine which is also [open source free software](https://github.com/nylas/sync-engine).

[![Build Status](https://travis-ci.org/nylas/N1.svg?branch=master)](https://travis-ci.org/nylas/N1)
[![Slack Invite Button](http://slack-invite.nylas.com/badge.svg)](http://slack-invite.nylas.com)
[![GitHub issues On Deck](https://badge.waffle.io/nylas/N1.png?label=on deck&title=On Deck)](https://waffle.io/nylas/N1)

# Download N1

You can download compiled versions of N1 for Windows, Mac OS X, and Linux (.deb) from [https://nylas.com/N1](https://nylas.com/N1). You can also build and run N1 on Fedora. A Fedora distribution is coming soon!

# Build A Plugin

Plugins lie at the heart of N1 and give it its powerful features. Building your own plugins allows you to integrate the app with other tools, experiment with new workflows, and more. Follow the [Getting Started guide](http://nylas.com/N1/getting-started/) to write your first plugin in 5 minutes.

If you would like to run the N1 source and contribute, check out our [contributing
guide](https://github.com/nylas/N1/blob/master/CONTRIBUTING.md).

# Plugin List
We're working on building a plugin index that makes it super easy to add them to N1. For now, check out the list below! (Feel free to submit a PR if you build a plugin and want it featured here.)

##### Themes
- [Dark](https://github.com/nylas/N1/tree/master/internal_packages/ui-dark)
- [Taiga](http://noahbuscher.github.io/N1-Taiga/) — Mailbox-inspired light theme
- [Predawn](https://github.com/adambmedia/N1-Predawn)
- [ElementaryOS](https://github.com/edipox/elementary-nylas)
- [Ubuntu](https://github.com/ahmedlhanafy/Ubuntu-Ui-Theme-for-Nylas-N1)
- [Ido](https://github.com/edipox/n1-ido) — Polymail-inspired theme
- [Solarized Dark](https://github.com/NSHenry/N1-Solarized-Dark)
- [Berend](https://github.com/Frique/N1-Berend)
- [LevelUp](https://github.com/stolinski/level-up-nylas-n1-theme)
- [Darkside](http://jamiewilson.io/darkside/)
- [Sunrise](https://github.com/jackiehluo/n1-sunrise)
- [Less Is More](https://github.com/P0WW0W/less-is-more/)

##### Composer
- [Translate](https://github.com/nylas/N1/tree/master/internal_packages/composer-translate) — Works with 10 languages
- [Quick Schedule](https://github.com/nylas/N1/tree/master/internal_packages/quick-schedule) — Show your availability to schedule a meeting with someone
- [Quick Replies](https://github.com/nylas/N1/tree/master/internal_packages/composer-templates) — Send emails faster with templates
- [Send Later](https://github.com/nylas/N1/tree/master/internal_packages/send-later) — Schedule your emails to be sent at a later time
- [Open Tracking](https://github.com/nylas/N1/tree/master/internal_packages/open-tracking) — See if your emails have been read
- [Link Tracking](https://github.com/nylas/N1/tree/master/internal_packages/link-tracking) — See if your links have been clicked
- [Emoji Keyboard](https://github.com/nylas/N1/tree/master/internal_packages/composer-emojis) — Insert emojis by typing a colon (:) followed by the name of an emoji symbol
- [Jiffy](http://noahbuscher.github.io/N1-Jiffy/) — Insert animated GIFs
- In Development: [PGP Encryption](https://github.com/mbilker/email-pgp)

##### Sidebar
- [GitHub Sidebar Info](https://github.com/nylas/N1/tree/master/internal_packages/github-contact-card)
- [Weather](https://github.com/jackiehluo/n1-weather)
- [Todoist](https://github.com/anopensourceguy/TodoistN1)

##### Navbar
- [View on GitHub](https://github.com/nylas/N1/tree/master/internal_packages/message-view-on-github)

##### Threadlist
- [Personal-level Indicators](https://github.com/nylas/N1/tree/master/internal_packages/personal-level-indicators)
- [Unsubscribe](https://github.com/colinking/n1-unsubscribe)

##### Messages
- [Phishing Detection](https://github.com/nylas/N1/tree/master/internal_packages/phishing-detection)
- [Squirt Speed Reader](https://github.com/HarleyKwyn/squirt-reader-N1-plugin/)

# Running Locally
By default the N1 source points to our hosted version of the Nylas Sync Engine; however, the Sync Engine is open source and you can [run it yourself](https://github.com/nylas/N1/blob/master/CONTRIBUTING.md#running-against-open-source-sync-engine).

# Feature Requests / Plugin Ideas

Have an idea for a package, or a feature you'd love to see in N1? Check out our
[public Trello board](https://trello.com/b/hxsqB6vx/n1-open-source-roadmap)
to contribute your thoughts and vote on existing ideas.
