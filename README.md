💌 Mailspring
====

[![Travis Status](https://travis-ci.org/Foundry376/Mailspring.svg?branch=master)](https://travis-ci.org/Foundry376/Mailspring)
[![AppVeyor Status](https://ci.appveyor.com/api/projects/status/iuuuy6d65u3x6bj6?svg=true)](https://ci.appveyor.com/project/Foundry376/Mailspring)



**Hello! I'm one of the original authors of Nylas Mail and this is a significant fork of the app which completely replaces JavaScript mail sync with a C++ core built on Mailcore2. Unfortunately, it's not ready for use - check back soon!**

![Mailspring Screenshot](https://github.com/Foundry376/Mailspring/raw/master/screenshots/hero_graphic_mac%402x.png)

High level Goals:
---

- Replace JavaScript mail sync (client-sync package) and the Electron "worker window" with a new, high performance codebase written in C++ and based on Mailcore2. Make the Electron application just the UI layer.
  + One C++ process per email account.
  + C++ and JS communicate via the child process stdin/stdout streams.
  + JS application queues tasks *but has read-only access to the database.*
  + JS application should not install timers or wake /at all/ when idle. 0% battery impact when idle.
- Improve performance of the thread list and composer contenteditable.
- Make windows open faster by just having less code.
- Bring back mail rules.


Roadmap and Progress:
---
See [ROADMAP.md](https://github.com/Foundry376/Mailspring/blob/master/ROADMAP.md)

----------------

**Mailspring is an open-source mail client built on the modern web with [Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).** It is designed to be extensible, so it's easy to create new experiences and workflows around email. Want to learn more? Check out the [full documentation](https://Foundry376.github.io/Mailspring/).

[![Slack Invite Button](http://slack-invite.getmailspring.com/badge.svg)](http://slack-invite.getmailspring.com)


## Download Mailspring

You can download compiled versions of Mailspring for Windows, Mac OS X, and Linux (.deb) from [https://getmailspring.com/download](https://getmailspring.com/download). You can also build and run Mailspring (Previously N1) on Fedora. On Arch Linux, you can install **[n1](https://aur.archlinux.org/packages/n1/)** or **[n1-git](https://aur.archlinux.org/packages/n1-git/)** from the aur.

## Build A Plugin

Plugins lie at the heart of Mailspring and give it its powerful features. Building your own plugins allows you to integrate the app with other tools, experiment with new workflows, and more. Follow the [Getting Started guide](https://Foundry376.github.io/Mailspring/) to write your first plugin in five minutes. To create your own theme, go to our [Theme Starter guide](https://github.com/nylas/N1-theme-starter).

If you would like to run the N1 source and contribute, check out our [contributing
guide](https://github.com/Foundry376/Mailspring/blob/master/CONTRIBUTING.md).

## Themes

The Mailspring user interface is styled using CSS, which means it's easy to modify and extend. Mailspring comes stock with a few beautiful themes, and there are many more which have been built by community developers

<center><img width=550 src="http://i.imgur.com/PWQ7NlY.jpg"></center>


#### Bundled Themes
- [Dark](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/ui-dark)
- [Darkside](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/ui-darkside) (designed by [Jamie Wilson](https://github.com/jamiewilson))
- [Taiga](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/ui-taiga) (designed by [Noah Buscher](https://github.com/noahbuscher))
- [Ubuntu](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/ui-ubuntu) (designed by [Ahmed Elhanafy](https://github.com/ahmedlhanafy))
- [Less Is More](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/ui-less-is-more) (designed by [Alexander Adkins](https://github.com/P0WW0W))



#### Community Themes
- [Arc Dark](https://github.com/varlesh/Nylas-Arc-Dark-Theme)
- [Predawn](https://github.com/adambmedia/N1-Predawn)
- [ElementaryOS](https://github.com/edipox/elementary-nylas)
- [Ido](https://github.com/edipox/n1-ido)—Polymail-inspired theme
- [Solarized Dark](https://github.com/NSHenry/N1-Solarized-Dark)
- [Berend](https://github.com/Frique/N1-Berend)
- [LevelUp](https://github.com/stolinski/level-up-nylas-n1-theme)
- [Sunrise](https://github.com/jackiehluo/n1-sunrise)
- [ToogaBooga](https://github.com/brycedorn/N1-ToogaBooga)
- [Material](https://github.com/jackiehluo/n1-material)
- [Monokai](https://github.com/dcondrey/n1-monokai)
- [Agapanthus](https://github.com/taniadaniela/n1-agapanthus)—Inbox-inspired theme
- [Stripe](https://github.com/oeaeee/n1-stripe)
- [Kleinstein] (https://github.com/diklein/Kleinstein)—Hide the account list sidebar
- [BoraBora](https://github.com/arimai/N1-BoraBora)
- [Honeyduke](https://github.com/arimai/n1-honeyduke)
- [Snow](https://github.com/Wattenberger/N1-snow-theme)
- [Hull](https://github.com/unity/n1-hull)
- [Express](https://github.com/oeaeee/n1-express)
- [DarkSoda](https://github.com/adambullmer/N1-theme-DarkSoda)
- [Bemind](https://github.com/bemindinteractive/Bemind-N1-Theme)
- [Dracula](https://github.com/dracula/nylas-n1)
- [MouseEatsCat](https://github.com/MouseEatsCat/MouseEatsCat-N1)
- [Sublime Dark](https://github.com/rishabhkesarwani/Nylas-Sublime-Dark-Theme)
- [Firefox](https://github.com/darshandsoni/n1-firefox-theme)
- [Gmail](https://github.com/dregitsky/n1-gmail-theme)
- [Darkish](https://github.com/dyrnade/N1-Darkish)

#### To install community themes:

1. Download and unzip the repo
2. In Mailspring, select `Developer > Install a Package Manually... `
3. Navigate to where you downloaded the theme and select the root folder. The theme is copied into the Mailspring settings folder for your convinence
5. Select `Change Theme...` from the top level menu, and you'll see the newly installed theme. That's it!


Want to dive in more? Try [creating your own theme](https://github.com/nylas/nylas-mail-theme-starter)!


## Plugin List
We're working on building a plugin index that makes it super easy to add them to Mailspring. For now, check out the list below! (Feel free to submit a PR if you build a plugin and want it featured here.)


#### Bundled Plugins
Great starting points for creating your own plugins!
- [Translate](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/composer-translate)—Works with 10 languages
- [Quick Replies](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/composer-templates)—Send emails faster with templates
- [Emoji Keyboard](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/composer-emoji)—Insert emoji by typing a colon (:) followed by the name of an emoji symbol
- [GitHub Sidebar Info](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/github-contact-card)
- [View on GitHub](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/message-view-on-github)
- [Personal Level Indicators](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/personal-level-indicators)
- [Phishing Detection](https://github.com/Foundry376/Mailspring/tree/master/internal_packages/phishing-detection)

## Configuration
You can configure Mailspring in a few ways—for instance, pointing it to your self-hosted instance of the sync engine or changing the interface zoom level. [Learn more about how.](https://github.com/Foundry376/Mailspring/blob/master/CONFIGURATION.md)

## Feature Requests / Plugin Ideas
Have an idea for a package or a feature you'd love to see in Mailspring? Search for existing [GitHub issues](https://github.com/Foundry376/Mailspring/issues) and join the conversation!
