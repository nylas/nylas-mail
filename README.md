![N1 Logo](https://edgehill.s3.amazonaws.com/static/N1.png)

![N1 Screenshot](https://nylas.com/static/img/home/screenshot-hero-mac@2x.png)

**N1 is an open-source mail client built on the modern web with [Electron](https://github.com/atom/electron), [React](https://facebook.github.io/react/), and [Flux](https://facebook.github.io/flux/).** It is designed to be extensible, so it's easy to create new experiences and workflows around email. N1 is built on the Nylas Sync Engine, which is also [open-source free software](https://github.com/nylas/sync-engine).

[![Build Status](https://travis-ci.org/nylas/N1.svg?branch=master)](https://travis-ci.org/nylas/N1)
[![Slack Invite Button](http://slack-invite.nylas.com/badge.svg)](http://slack-invite.nylas.com)
[![GitHub issues On Deck](https://badge.waffle.io/nylas/N1.png?label=on deck&title=On Deck)](https://waffle.io/nylas/N1)

#### Want to help build the future of email? [Nylas is hiring](https://jobs.lever.co/nylas)!

# Download N1

You can download compiled versions of N1 for Windows, Mac OS X, and Linux (.deb) from [https://nylas.com/N1](https://nylas.com/N1). You can also build and run N1 on Fedora. On Arch Linux, you can install **[n1](https://aur.archlinux.org/packages/n1/)** or **[n1-git](https://aur.archlinux.org/packages/n1-git/)** from the aur.

# Build A Plugin

Plugins lie at the heart of N1 and give it its powerful features. Building your own plugins allows you to integrate the app with other tools, experiment with new workflows, and more. Follow the [Getting Started guide](https://nylas.github.io/N1/getting-started/) to write your first plugin in five minutes. To create your own theme, go to our [Theme Starter guide](https://github.com/nylas/N1-theme-starter).

If you would like to run the N1 source and contribute, check out our [contributing
guide](https://github.com/nylas/N1/blob/master/CONTRIBUTING.md).

# Themes

The Nylas N1 user interface is styled using CSS, which means it's easy to modify and extend. N1 comes stock with a few beautiful themes, and there are many more which have been built by community developers

<center><img width=550 src="http://i.imgur.com/PWQ7NlY.jpg"></center>


#### Bundled Themes
- [Dark](https://github.com/nylas/N1/tree/master/internal_packages/ui-dark)
- [Darkside](https://github.com/nylas/N1/tree/master/internal_packages/ui-darkside) (designed by [Jamie Wilson](https://github.com/jamiewilson))
- [Taiga](https://github.com/nylas/N1/tree/master/internal_packages/ui-taiga) (designed by [Noah Buscher](https://github.com/noahbuscher))
- [Ubuntu](https://github.com/nylas/N1/tree/master/internal_packages/ui-ubuntu) (designed by [Ahmed Elhanafy](https://github.com/ahmedlhanafy))
- [Less Is More](https://github.com/nylas/N1/tree/master/internal_packages/ui-less-is-more) (designed by [Alexander Adkins](https://github.com/P0WW0W))



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
- [Slack](https://github.com/jodyheavener/N1-Slack) inspired theme
- [MDL](https://github.com/Rawnly/n1-mdl) - based on [Google MDL Palette](https://material.google.com/style/color.html#color-color-palette)

#### To install community themes:

1. Download and unzip the repo
2. In Nylas N1, select `Developer > Install a Package Manually... `
3. Navigate to where you downloaded the theme and select the root folder. The theme is copied into the `~/.nylas` folder for your convinence
5. Select `Change Theme...` from the top level menu, and you'll see the newly installed theme. That's it!


Want to dive in more? Try [creating your own theme](https://github.com/nylas/N1-theme-starter)!


# Plugin List
We're working on building a plugin index that makes it super easy to add them to N1. For now, check out the list below! (Feel free to submit a PR if you build a plugin and want it featured here.)


#### Bundled Plugins
Great starting points for creating your own plugins!
- [Translate](https://github.com/nylas/N1/tree/master/internal_packages/composer-translate)—Works with 10 languages
- [Quick Replies](https://github.com/nylas/N1/tree/master/internal_packages/composer-templates)—Send emails faster with templates
- [Emoji Keyboard](https://github.com/nylas/N1/tree/master/internal_packages/composer-emoji)—Insert emoji by typing a colon (:) followed by the name of an emoji symbol
- [GitHub Sidebar Info](https://github.com/nylas/N1/tree/master/internal_packages/github-contact-card)
- [View on GitHub](https://github.com/nylas/N1/tree/master/internal_packages/message-view-on-github)
- [Personal Level Indicators](https://github.com/nylas/N1/tree/master/internal_packages/personal-level-indicators)
- [Phishing Detection](https://github.com/nylas/N1/tree/master/internal_packages/phishing-detection)

#### Community Plugins

Note these are not tested or officially supported by Nylas, but we still think they are really cool! If you find bugs with them, please open GitHub issues on their individual project pages, not the N1 repo page. Thanks!
- [Thread Age](https://github.com/jodyheavener/N1-Thread-Age)
- [Jiffy](http://noahbuscher.github.io/N1-Jiffy/)—Insert animated GIFs
- [Weather](https://github.com/jackiehluo/n1-weather)
- [Todoist](https://github.com/alexfruehwirth/N1TodoistIntegration)
- [Unsubscribe](https://github.com/colinking/n1-unsubscribe)
- [Squirt Speed Reader](https://github.com/HarleyKwyn/squirt-reader-N1-plugin/)
- [Website Launcher](https://github.com/adriangrantdotorg/nylas-n1-background-webpage)—Opens a URL in separate window
- In Development: [Cypher](https://github.com/mbilker/cypher) (PGP Encryption)
- [Avatars](https://github.com/unity/n1-avatars)
- [Events Calendar (WIP)](https://github.com/nerdenough/n1-events-calendar)
- [Mail in Chat (WIP)](https://github.com/yjchen/mail_in_chat)
- [Evernote](https://github.com/grobgl/n1-evernote)
- [Wunderlist](https://github.com/miguelrs/n1-wunderlist)
- [Participants Display](https://github.com/kbruccoleri/nylas-participants-display)

When you install packages, they're moved to ~/.nylas/packages, and N1 runs apm install on the command line to fetch dependencies listed in the package's package.json


# Configuration
You can configure N1 in a few ways—for instance, pointing it to your self-hosted instance of the sync engine or changing the interface zoom level. [Learn more about how.](https://github.com/nylas/N1/blob/master/CONFIGURATION.md)

# Feature Requests / Plugin Ideas

Have an idea for a package or a feature you'd love to see in N1? Check out our
[public Trello board](https://trello.com/b/hxsqB6vx/n1-open-source-roadmap)
to contribute your thoughts and vote on existing ideas.
