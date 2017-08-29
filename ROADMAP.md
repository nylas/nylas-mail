## Roadmap to Initial Release:

Target Ship Date: Late September

#### C++ MailSync
*Goal: Reduce bugginess and battery impact, enable new controls over what mail data is synced, and dramatically improve performance by moving mailsync to a new C++ codebase based on MailCore2.*

- [x] Build a lightweight C++ command-line application that syncs mail using `MailCore2` and `libcurl` and writes to the same sqlite3 database schema used by Merani.
- [x] Remove the client-sync package and the Activity window and implement `MailsyncProcess`/`MailsyncBridge` wrappers around new C++ codebase. Broadcast database events from the C++ app into the JavaScript app so the UI updates as data changes.
- [x] Remove thread and contact search indexing, perform indexing as data is retrieved from IMAP in C++.
- [x] Remove migration support from JavaScript. Run the C++ app at launch with `--migrate` to run migrations before the main window is displayed.
- [x] Make the DatabaseStore in the JavaScript application read-only. All changes to all models flow through C++ worker for that account.
- [x] Rewrite the task queue to dispatch tasks to C++ and watch for table changes rather than executing tasks in JavaScript.
- [x] Rewrite all mail triage tasks (flag changes, folder changes, label changes) in C++ and update JS code to dispatch tasks to the C++ codebase.
- [x] Rewrite sync progress reporting to use new metrics attached to Folder models
- [x] Refactor the way the JavaScript front-end references "Labels" and "Folders" to reflect the fact that Gmail has both labels and folders, not just labels and "special labels with weird behavior."
- [x] Refactor the `FileUploadStore` and `FileDownloadStore` into a single `AttachmentStore`. Remove all uploading / downloading from JavaScript.
- [x] Rewrite the onboarding flow to spawn a C++ worker to check IMAP/SMTP credentials.
- [x] Rewrite the SendDraftTask in C++
  - [x] Basic implementation
  - [x] Ensure errors are presented in JavaScript and re-open the message window
  - [x] Ensure "multisend" works and metadata is transferred to the new message
  - [x] Ensure the message is saved to the Sent Folder
- [x] Store IMAP/SMTP credentials and the cloud API token in the keychain securely.
- [x] Find a cross-platform solution for reliable C++ stack traces
- [x] Ensure C++ worker crashes are reported through Sentry or Backtrace
- [ ] Restart C++ workers if they crash and alert the user to repeated errors.
- [x] Add support for Gmail authentication flow and XOAUTH2
- [ ] Add more robust retry / failure handling logic to C++ code.
- [x] Decide what license to use for the C++ codebase / whether to open-source it or provide binaries. (Update: I've deciced to keep this closed source for now. [Here's why.](#why-is-mailsync-closed-source))
- [x] Link the C++ codebase into Merani as a submodule, make Travis and AppVeyor CI build the C++ codebase.

#### C++ MailSync Testing:
- [x] Test with a Gmail account
- [x] Test with a FastMail account
- [ ] Test with a Yahoo account
- [ ] Test with an iCloud account
- [ ] Test with a AOL account
- [ ] Test with an insecure IMAP/SMTP account
- [x] Test that "multisend" works for open/link tracking
- [x] Test that sending errors are shown in JavaScript

#### Cloud Services
*Goal: Provide equivalent infrastructure that will allow snooze, send later, to continue working, autoupdating of the app, etc.*

- [x] Re-implement Identity services (billing.nylas.com)
  + [x] Implement basic sign in / create your account pages and token-based auth
  + [x] Implement autoupdate and download endpoints for Mac, Win, Linux
  + [~] Implement billing dashboard for paid version

- [x] Re-implement Accounts services ("Edgehill" API):
  + [x] Implement storage of key-value metadata for threads, messages and contacts.
  + [x] Implement delta stream that sends metadata changes to the app (eg: when an email is opened.)
  + [x] Implement delta stream handling in the C++ codebase

#### Deployment
- [x] Create a new AWS account for Merani project
- [x] Create a Stripe account
- [x] Register Merani domain(s)
- [x] Setup Sentry for client error reporting
- [x] Setup Sentry for server error reporting
- [x] Obtain Mac Developer Certificate for Merani
- [ ] Obtain Windows Verisign Certificate for Merani
- [x] Setup Amazon VPC with public/private subnets, strong security group rules 
- [x] Setup fast, reproducible deployments w/ Docker containers
- [x] Deploy new identity API to id.getmerani.com
- [ ] Deploy new accounts API to accounts.getmerani.com
- [ ] Deploy cloud workers to a secured AWS VPC
  *Blocked: Waiting for Nylas to open-source the rest of the code.*

#### General
- [ ] Create a new logo / icon for Merani
- [x] Bump Electron to 1.7.6
- [x] Bump React to 15.x
- [x] Remove "heavy" Node modules no longer needed in 2017 and contribute to slow launch time:
  *Bluebird, Q, node-request, etc.*
- [x] Re-implement package manager to support two-phase loading. Get the window onscreen faster and wait to load non-essential plugins.
- [x] Stop transpiling async/await which are now supported by Electron
- [~] Rewrite all CoffeeScript in modern JavaScript. See [this spreadsheet](https://docs.google.com/spreadsheets/d/1DsZhrNEzCTBlsrPo82UkUxSgqj_fkGRcgTQ-lurnq7c) for progress.
- [ ] Figure out why the composer contenteditable selection freaks out sometimes (related to upgrading Electron + Chromium?) Composer is not shippable ATM.
- [ ] QA the entire application

-----

## Roadmap Past 1.0
- [ ] Bring back Mail Rules!
- [ ] Update documentation for creating plugins and themes
- [ ] Create help site using existing content from support.getmerani.com.
  *Verify they are OK with this?*
- [ ] Implement plugin / theme browser like the Chrome Web Store.
  + Decide whether to restore support for plugins that need native modules.
- [ ] Localize the app into other languages
- [ ] Improve Linux support (find a maintainer interested in focusing on Linux?)
- [ ] Overhaul the rich text composer:
  + It's currently pretty slow and degrades the overall experience. Initially we wanted to support editing reply text / inline replies, and this has come at a high cost. Investigate using Draft.JS instead of our custom composer.
- [ ] Add options for controlling the size of the message cache
  + Only sync the last "X" months of mail headers
  + Only sync the last "X" months of mail bodies / attachments
  + Omit certain folders
- [ ] Create new plugins:
  + Receipts
  + Templates with per-template performance tracking
  + Groups
  + Files

## Why is Mailsync Closed Source?

For the initial release I've decided to keep the new C++ codebase closed-source. When you pull this repository and run `npm install`, the correct Mailsync build for your platform is automatically downloaded and put in place so you can hack away on the Merani Electron app. For those of you who are interested, here's why it's closed-source:

- **Open source is a commitment.** When I was the lead engineer of the Nylas Mail team at Nylas, I spent thousands of hours responding to GitHub issues, helping people build the source, and trying to give PR feedback that was actionable and kind. I'm expecting to spend about 30% of my time working with the open-source community on the JavaScript side of Merani, and I'd rather focus on improving existing documentation and hackability than expand code surface area past what I can support. Especially until it's past the ["bus factor"](https://en.wikipedia.org/wiki/Bus_factor) of one!

- **Mailsync is hard to compile.** Mailsync is written in C++0x and uses new features like `shared_ptr` and `condition_variable`. It requires GCC 4.8 and has a ton of dependencies and required build flags. If `node-sqlite3` is any indication, open-sourcing it in it's current form would be a GitHub Issues disaster. (Compared to mailsync, `node-sqlite3` is pretty easy to build but a whopping *35%* of it's open issues are [compilation-related!](https://github.com/mapbox/node-sqlite3/issues?utf8=%E2%9C%93&q=is%3Aissue%20is%3Aopen%20compile) 😰).

- **The odds of great PRs are low.** Mailsync is a multithreaded, cross-platform C++ application that interfaces with old, fragile protocols that have their own learning curves and are difficult to mock. For folks to contribute meaningful pull requests, I'd have to write great docs and tests. I'd also need to spend a /lot/ of time reviewing changes for side-effects, enforcing good C++ techniques, and checking changes for performance impact. Maybe I'll be able to support this in the future, but not yet!

If you're interested in contributing to the Merani Mailsync codebase and have some time and skill to throw at it, please let me know!

