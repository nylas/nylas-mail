# N1 Changelog

### 0.4.51 (9/1/16)

- Features:

  + Onboarding flow improvements:
    + Allow HTTPS in self-hosted sync engine onboarding
    + Add new UI component for OAuth sign-in
    + No longer show welcome page
  + Add markdown composer plugin

- Fixes:

  + We now correctly display message timestamp in the message list.
  + No longer show tokens in developer api bar.
  + Fix composer contact chip styles on Windows.
  + Fix webview issues for onboarding flow.
  + Fix issue with blank config.json (#2518)

- Development:

  + Add PackageMigrationManager which allows us to migrate external packages
    into the N1 build and specify whether newly added packages should be enabled or
    disabled by default


### 0.4.49 (8/18/16)

- Features:

  + 24h clock: You can now choose to view times in the app in 24h clock format. You
    can select this option within the General Preferences.
  + Installer: Adds a new notification bar for mac users only that warns you if
    N1 is not in your Applications folder, and gives you the option to move it to your
    Applications folder. This prevents errors that can prevent you from receiving
    autoupdates.

- Fixes:

  + We now display better error messaging when we can't save your credentials
    to the system keychain.
  + Phishing detection now uses case insensitive detection when inspecting
    emails.
  + Issues connecting to the Clearbit and Keyabse API's are now resolved.
  + Fixed issue where new windows wouldn't refresh themselves.
  + Long signatures inside preferences can now be scrolled.
  + You can now correctly select to enable link tracking or open tracking
    independently when sending and tracking multiple recipients.
  + When clicking the top of the composer body, the top of the text content is
    now correctly focused, rather than the end.
  + The subject field is now correctly focused when a composer is opened via a
    mailto link.
  + MailMerge will no longer error when trying to send after previewing contents
    as the recipients will recieve them. Also, the cursor styles for MailMerge tokens
    have been updated to indicate that they can be dragged.
  + We don't open dev tools when `applyTransformsToDraft` fails when sending.
  + The autoupdater now properly uses your Nylas ID when available.
  + We no longer retry send, and just show an error dialog when sending fails.


### 0.4.47 (7/28/16)

- Features:

  + Signatures: You can now create as many signatures as you want, make them
    the default for accounts and aliases, and choose which one to apply to a
    draft!

  + Snooze & Send Later: We've made snooze and send later more responsive. They
    now act on your email within one minute of your scheduled time.

  + Linux Unread Badge: On Linux systems with the Unity Launcher, an unread count
    appears on the app icon.

  + Keybase: We've improved decryption support and messaging in the Keybase plugin,
    making it even easier to encrypt and decrypt your email.

- Fixes:
  + N1 now supports email addresses and URLs containing unicode characters. #1920
  + The composer no longer lags significantly when replying to emails with large
    amounts of quoted text.
  + Inline images render properly in emails that specify a "base" URL in their HTML.
  + HTML emails with a body height of `100%` or `inherit` now render
    at the correct height instead of appearing 10px tall. #1280
  + Reading emails now removes related system notifications #1393
  + Notifications are now displayed in the correct order as they are received #2517
  + Mail merge no longer complains about empty rows, and removing a column no
    longer removes data from other columns when some rows are missing values.
  + When you delete a folder, it now disappears immediately.
  + When closing a draft, your most recent changes reliably appear in the draft list.
  + Emails sent from Outlook for Mac that contain `contenteditable` nodes no longer
    appear to be editable when viewed in N1.
  + "Per recipient" read receipts and open tracking are no longer enabled when
    you're sending to more than 10 people, since they can cause you to go over
    your provider's sending quota more quickly.
  + On linux, the menu bar automatically hides. #1181
  + In Preferences > General, a new option allows you to clear your local cache
    and / or reset your accounts in N1.
  + In Preferences > General, a new option allows you to disable spellcheck.
    Note: You must relaunch N1 for this setting to take effect.
  + When N1 prompts you to "Sign in to Gmail", it displays the authentication URL
    so you can copy it if the page does not appear in your browser properly.
  + When saving several attachments, N1 does not repeatedly open the same Finder window. #1044
  + If you've disabled the Important label in Gmail preferences, you no longer see
    a lowercase `important` label on your mail.
  + We now support Linux Mint 18
  + The "View on Github" plugin now works as expected.
  + Renaming a label inside another label now maintains the hierarchy as expected. #2402

- Development:

  + Local Sync Engine: When you first setup N1, you can choose to link it to a
    version of the sync engine on your local machine. This is a developer / hacker
    feature and we recommend you use the hosted infrastructure! Creating a Nylas
    Identity is no longer required when using a custom environment.

### 0.4.45 (6/14/16)

- Features:
  + Nylas Identity: This month we're [launching Nylas Pro](https://nylas.com/blog/nylas-pro/).
    As an existing user, you'll receive a coupon for your first year free.
    Create a Nylas ID to continue using N1, and look out for a coupon email!

  + Read Receipts: You can now see which recipients read your emails and clicked
    links (Gmail and IMAP only!) Click the purple eye on an email, or look in the
    Activity view for details.

  + Encryption powered by Keybase: Enable the new Encryption plugin to quickly and
    easily encrypt messages in the composer using public keys found on Keybase.

  + Account Management: A new, refined authentication process makes it easy to
    link accounts and auto-completes settings for hundreds of email services.

  + QuickSchedule: You can now place “Propose Times” and “Meeting Request”
    event cards anywhere in your message body.

  + Mail Merge: You can now preview emails as a recipient, drag and drop tokens
    within the message body, and more. Mail merge is also more robust at sending
    large sets of emails.

  + Unified “Important” is now displayed in Unified Inbox when one or more Gmail
    accounts are present.

- Fixes:
  + A new option allows you to use a 24-hour clock within N1.
  + A new option allows you to show the total number of messages on the app’s badge icon.
  + N1 no longer tries to adapt Outlook emoji, fixing a bug where images would become
    emoji in some cases.
  + N1 no longer hangs after restarting when it was in the middle of sending an email.
  + N1 waits longer for Exchange AutoDiscovery to complete (2+ minutes).
  + When editing a draft queued for sending in the past, times no longer indicate the future.
  + The Activity view only shows activity from the currently focused email account(s).
  + A "Window" menu is now present on Linux and Windows so you can open the Developer Tools.
  + When changing labels, the toasts at the bottom of the window are more succinct.
  + After switching themes, the next composer opens with the correct theme.
  + Updates to your accounts no longer cause your selected thread to be de-selected.
  + The search index no longer contains duplicates in some scenarios, which
    made it impossible to view search results.
  + Messages no longer fail to render when using N1 in some specific timezones.
  + Accented characters are now supported in template names.
  + A new hotkey (default: z) allows you to Snooze mail with the keyboard.
  + "Add Folder / Label" is shown in the sidebar when you hover anywhere in a
    section, making it more discoverable.
  + Labels / folders shown in the picker are now sorted the way they appear in the sidebar.
  + Empty state images are now included for important and spam views.
  + Re-ordering of mail rules now works as expected.
  + The RPM linux version of N1 now links against the correctly named keyring dependency.
  + Trying to connect to the Nylas API with a very old cursor no longer results
    in an infinite loading loop in some scenarios.


### 0.4.40 (5/19/16)

- Fixes:
  + `Config.json` is no longer mangled at launch in some scenarios, which caused
    the app to log you out. JSON parsing errors are also handled more gracefully.
  + Clicking "Propose Times" in a composer window no longer crashes N1.
  + When using Mail Merge, N1 still warns you about missing body, subject line, etc.
  + "Sending in X minutes" is no longer displayed for Snooze / Send Later dates in the past.
  + Message indexes are now created properly, resolving issues where incorrect drafts
    could be synced or sent in some scenarios.
  + On Windows, installing the update no longer displays a dialog "`app-0.4.X` is a folder."
  + Undoing and then redoing many operations now works as expected.
  + When removing accounts, N1 focuses the remaining accounts properly.
  + N1 no longer fails to quit in some scenarios.
  + N1 is now ~60MB smaller and launches faster thanks to proper precompiling of assets.
  + Spellcheck now runs faster.

- Development:
  + When installing third party plugins, we now use the `name` from your package.json
    rather than the folder name, resolving an issue where plugins would be installed
    as `my-plugin-master` when downloaded from GitHub.


### 0.4.37 (5/15/16)

- Features:
  + Keyboard Shortcuts: Edit your keyboard shortcuts directly from the keyboard
    shortcuts preferences screen.
  + You can now include variables in the subject line of mail merge emails.

- Fixes:
  + The `--background` flag now properly opens N1 in the background.
  + Switching to `dev` mode from the Developer menu works as expected.
  + Dragging files onto the dock icon to attach them to a new email works properly.
  + N1 handles HTTP errors in addition to socket errors during attachment download.
  + N1 asks you to re-authenticate if your account has been cleaned up after a long period of inactivity.
  + N1 no longer gets stuck into an infinite loop in some scenarios when your sync token is very old.
  + The INBOX. folder prefix is hidden for FastMail accounts.
  + When viewing your spam folder, you can now "Unmark" something as spam.
  + When resuming from sleep, N1 no longer plays the "new mail" sound repeatedly / loudly.
  + The empty animation no longer plays briefly when the app launches.
  + Search queries with double quotes (") now work as expected.
  + Changes to your accounts no longer cause the account's inbox to become focused.
  + Replies honor the ReplyTo field, even if the message is from one of your accounts.
  + Using the Apple Mail keyboard layout, Cmd+[ and Cmd+] move between threads.
  + The Message Viewer always appears in the Window menu and is bound to Cmd/Ctrl+0.
  + `?` now shows your keyboard shortcuts.
  + On Linux, N1 now notes that `libappindicator1` is required for the system tray.
  + Function-key keyboard shortcuts are shown in the menu.

- Design:
  + The confusing spam icon has been replaced with "thumbs down".
  + The standard "Dark" theme uses more balanced dark colors.
  + The personal level indicators are better designed.
  + The search bar hides properly in `Darkside` when items are selected.

- Development:
  + We've upgraded to Babel 6 and the latest version of ESLint.
  + N1 no longer builds on Node 0.10, Node 0.11 or Node 0.12. Use Node 4+ when
    running `script/build` or `script/bootstrap`
  + N1 now uses the native implementations of all available ES2016 features.
  + N1 now uses Electron 1.0.1.
  + The codebase is now only 50% CoffeeScript
  + `script/bootstrap` no longer produces red-herring errors.


### 0.4.33 (5/4/16)

- Fixes a critical issue with "Send Later" state not sticking.
- Fixes an issue with the emoji popup menu in the composer not inserting emoji.
- Fixes a bug where "Read Receipts" and "Link Tracking" would not default to off after being turned off.
- Fixes the "delete" keyboard shortcut on Windows and Linux.
- Fixes the "g i" and other shortcuts which should return you to the thread list.

- The "archive or delete" option in preferences now mentions that it impacts swipe gestures.
- Right click "Copy Link" is now "Copy Link Address"
- Items in the sidebar auto-expand when you hover over them while dragging
- Third party `N1-Unsubscribe` plugin should now work when re-downloaded

### 0.4.32 (5/2/16)

- Features:
  + Mail Merge: Sending a lot of email? Compose a message, enable mail merge, and use
    a CSV file to send it to many recipients. Note that mail is still sent from your
    personal address, and provider rate limits may apply.

  + Activity View: Receive notifications as recipients interact with messages you send
    with read receipts and link tracking enabled. More activity improvements are coming soon!

  + Unread: A new view in the sidebar allows you to view all unread emails in your inbox.

  + Menus: N1's menus now include many more of the available keyboard shortcuts.

- Performance:
  + Secondary windows, like the calendar picker, open faster.
  + N1 uses ~20% less RAM, thanks to hot window optimizations.
  + Unified Starred, Drafts, and Unread views load faster thanks to SQLite partial indexes.

- Improvements:
  + The thread list no longer becomes detached in some scenarios, causing archive
    and other actions not to take effect.
  + Fixes a regression, allowing you to create lists by typing `- `.
  + Fixes a hard loop when trying to launch with a very old sync cursor.
  + A unified "spam" folder is now available alongside Inbox, Sent, etc.
  + Shift+J and Shift+K now allow you to select multiple threads in the Gmail and Inbox shortcut sets.
  + Command-clicking links on Mac OS X opens them behind N1.
  + Names like "Gotow, Ben (USA)" are now properly parsed into first and last names.
  + "Launch on System Start" is now compatible with XDG-compliant Linux desktops.
  + Inline image attachments less than 12k no longer cause the attachments icon
    to be shown, since they are almost always signatures.
  + You can now open the theme picker from the appearance preferences panel.
  + When viewing messages, URLs that contain email addresses are now "linkified" properly.
  + URLs always show their target on hover, even if overridden in the message HTML.
  + Trying to open CC or BCC no longer collapses the participants fields on slow computers.
  + On Mac OS X, open and save dialogs are attached to the window toolbar correctly.
  + On Mac OS X, the status bar icon for N1 now inverts correctly when clicked.
  + Opening N1 to the Drafts view now works as expected.
  + Viewing Outlook emails with emoji no longer results in bad HTML styling.
  + Empty emails with open or link tracking enabled are no longer saved when closed.
  + Read receipts are no longer included in quoted text when creating new messages.
  + Paste and match style now uses the correct shortcut on Mac OS X.
  + The Window menu now lists all the open windows.
  + The GitHub sidebar now correctly shows repos with the most stars when the user
    has many pages of repositories.
  +

- Developer:
  + N1 now uses React `0.15` and Electron `0.37.7`
  + Composer React components can now access the `session` and `draft` as props,
    rather than just the `draftClientId`.
  + We've removed `space-pen`, `jQuery` and several other dependencies.
  + Keymaps and menus in packages must now be in `JSON` format rather than `CSON`
  + The `KeymapManager` and `MenuManager` have been re-written to remove unwanted
    features and weight we inherited from Atom and improve compatibility with our
    React-based stack. CSS selectors are no longer used to scope anything.
  + Menus are now specified using Mousetrap syntax. `CmdOrCtrl-A` => `mod+shift+a`
  + This update transitions `config.cson` to `config.json`. We will be removing
    `CSON` support in an upcoming release.

### 0.4.25 (4/12/16)

- Features:
  + Search: N1 now performs client-side search and streams results from backend providers,
    dramatically improving search performance.

  + Quick Schedule: Create events and propose meeting times right from the composer. We've
    overhauled the design and implementation of the old Quick Scheduler, and more calendar
    features are coming soon.

  + Offline Status: N1 now displays a notice when it's disconnected from the API, so it's easy
    to tell if your mailbox is up-to-date.

- Performance:
  + We've redesigned the join tables that back the thread list, improving unified inbox
    loading speed ~53%.

- Bugs:
  + N1 now ships with emoji artwork so emoji aren't missing or incomplete on many platforms.
  + The thread list updates more quickly following rapid mailbox actions.
  + Thread drag-and-drop now works properly in all scenarios.
  + Messages with invalid dates no longer cause N1 to crash.
  + The thread list no longer displays an empty state briefly when loading.
  + Sync progress in the sidebar no longer appears in some scenarios after sync has finished.
  + Images with no width or height are now correctly scaled to the viewport size in emails.
  + BCC'd recipients are no longer listed in headers when forwarding a message.
  + `.ly` links and many others are now automatically highlighted in emails correctly.
  + Read receipts no longer throw exceptions when the only message on a thread is a draft.
  + The "Process All Mail" option in mail rules preferences now only processes the inbox,
    and never skips threads.
  + Themes with dashes in their folder names no longer break the theme picker.
  + N1 always handles mailto: links itself rather than launching the default client.
  + Inline images now load properly in all scenarios and display a progress indicator as they download.
  + The preferences interface has a brand new look!

- Development:
  + SQLite table names no longer contain dashes.
  + N1 now uses React `0.14.7`, will be moving to 15 very soon.
  + 12% fewer LOC in CoffeeScript than `0.4.19`! We are slowly moving N1 to ES2016.

### 0.4.19 (3/25/16)

- Features:
  + Inbox Zero: Beautiful new inbox zero artwork and a refined tray icon on Mac OS X!
  + Reply from Alias: N1 now chooses the alias you were emailed at for a reply.
  + Emoji: The emoji picker is now available in the bottom toolbar of the composer, and includes tabs and search!
  + Download All: A new button allows you to quickly download all attachments in a message.
  + Drop to Send: You can now drop files on the N1 app icon on Mac OS X to attach them to a new email!
  + Default Signature: This version of N1 includes a default signature. You can remove it
    by visiting `Preferences > Signatures`

- Design:
  + We've overhauled the multiple-selection UI to avoid toolbar issues.
  + Thanks to nearly a dozen pull requests, many of the bundled themes have received visual polish
  + Attachments have a refined design and better affordance for interaction.
  + The "pop-out" button is always visible when composing in the main window.
  + We've cleaned up the variables available to theme developers and created a starter kit for creating themes:
    [https://github.com/nylas/N1-theme-starter](https://github.com/nylas/N1-theme-starter)

- Fixes:
  + N1 no longer incorrectly quotes forwarded message bodies.
  + N1 API tokens are now stored in the system keychain for enhanced security.
  + Filesystem errors (no disk space, wrong permissions, etc.) are presented when uploading or downloading attachments.
  + Double-clicking image attachments now opens them.
  + When you receive email to an alias, replies are sent from that alias by default.
  + Search works more reliably, waits longer for results, and displays errors when results cannot be loaded.
  + Read receipts are now visible in the narrow thread list.
  + The undo/redo bar no longer appears when returning to your mailbox from Drafts.
  + N1 no longer hangs while processing links in very large emails.
  + The first input is auto-focused as you move through the Add Account flow.
  + Failing API actions are retried more slowly, reducing CPU load when your machine is offline.
  + The emoji keyboard now inserts emoji for a wider range of emoji names.
  + You can now select a view mode from the View menu.
  + Interface zoom is now an "advanced option", and has been removed from the preferences.

- Developer:
  + Composer Extensions using `finalizeSessionBeforeSending:` must now use `applyTransformsToDraft:`
  + A new `InjectedComponentSet` allows you to add icons beside user's names in the composer.
  + N1 is slowly transitioning to ES6 - 20% of package code was converted to ES6 this month!

### 0.4.16 (3/18/16)

This is a small patch release resolving the following issues:

- The red "Account Error" bar no longer appears incorrectly in some scenarios.
- The "Sent Mail" label is no longer visible on threads (normally this label is hidden)
- Unread counts are now correct and match your mailbox.
- N1 now backs off when API requests fail temporarily (Gmail throttling, etc.)
- Contact sidebar API requests retry on 202s from our backend provider.

### 0.4.14 (3/10/16)

- Features:

  + Overhauled Sidebar: The sidebar now shows more accurate contact information,
    recent conversations with the selected participant, and more.

  + Themes: A brand new theme picker (in the Application Menu) allows you
    to quickly try different themes, and we've bundled two great community themes
    (Darkside and Taiga) into the app! An updated dark theme is coming soon.

- Fixes:
  + Warnings now appear in the main window if we are unable to connect to your email provider.
  + The Send Later, Snooze and read receipts plugins now alert you if you are not using our hosted infrastructure.
  + The Autoload Images and Snooze date input field is now locale-aware.

  + Composer:
    + N1 cleans up drafts properly after sending if an autosave occurred immediately
      before your message was sent.
    + The emoji picker now matches emoji against more common words, like `:thumbsup`!
    + Link tracking correctly modifies only `http://` and `https://` links
    + When sending two responses to the same email, the second email no longer appears
      to be sending in some scenarios.

  + Reading:
    + Messages now show a loading indicator while they're being downloaded, and you can
      retry if the download is interrupted.
    + The "Sent" view now orders your messages by "last sent message".
    + The "At 2:30PM, Mark wrote..." byline is now recognized as part of quoted text.
    + Deleted messages are filtered from the conversation view, and you can show them by
      clicking "Show Deleted   Messages." Threads in trash and spam are also excluded from
      the Starred and Gmail label views.
    + "Archive" no longer removes the label you are currently viewing.
    + Delete and backspace no longer follow Gmail's "remove from view" behavior.
      For Gmail's behavior, use the `y` shortcut.

  + Attachments:
    + Downloads that fail are now retried properly when you interact with them.
    + Changing an attachment name when saving it no longer clears the file extension.

  + Account Setup:
    + The "Welcome to N1" screens now emphasize that it is cloud-based.
    + You can use IP addresses as IMAP / SMTP and Exchange domains.
    + You can now check "Require SSL" during IMAP / SMTP setup and N1 will not try plaintext authentication.
    + N1 now displays better error messages for a wide variety of auth issues.
    + Themes are no longer applied in the account setup window.

- Temporary:
  + N1 no longer syncs Drafts with Gmail, avoiding several critical issues our
    platform team is working to resolve. (Drafts duplicating or appearing sent as you edit.)

- Cleanup:
  + All sample plugins have been converted from CoffeeScript to ES2016.
  + The `<Popover>` component has been deprecated in favor of `<FixedPopover>` which is more flexible.
  + Running specs from the application no longer resets your account configuration.
  + N1 no longer adds `N1` and `apm` to `/usr/bin`

### 0.4.10 (2/25/16)

- Fixes:

  + Prevent accounts from being wiped by rapid writes to config.cson
  + Present nice error messages when sending results in 402 Message Rejected
  + Fix a regression in adding / removing aliases
  + Fix a regression in the Windows and Linux system tray icons
  + Fix an issue with deltas throwing exceptions when messages are not present
  + Stop checking for plugin auth once authentication succeeds. Makes "snooze"
    animation more fluid and performant.
  + Fix "Manage Templates" button in the pop-out composer.
  + Right-align timestamps in the wide thread list.
  + Fix print styling
  + Add "Copy Debug Info to Clipboard", making it easier for users to collect
    debugging information about messages.
  + Update the email address used for reporting quoted text and rendering issues.

### 0.4.9 (2/25/16)

[Read about this release on Medium](https://medium.com/@Nylas/nylas-n1-now-has-snooze-swipe-actions-emoji-and-more-561cd1e91559)

- Features:

  + Snooze: Schedules threads to return to your inbox in a few hours, a few days,
   or whenever you choose.

  + Swipe Actions: In the thread list, swipe to archive, trash or snooze your mail.
    Swiping works with the Mac trackpad and with Windows / Linux touchscreen devices.

  + Send Later: Choose “Send later” in the composer and pick when a draft should be sent.
    These scheduled drafts are sent via the sync engine, so you don’t need to be online.

  + Read Receipts and Link Tracking: Get notified when recipients view your message
    and click links with new read receipts and link tracking built in to the composer.

  + Emoji Picker: Type a `:` in the composer followed by the name of an emoji to
    insert it into your draft.

- Design:

  + This release includes slimmer toolbars and new icons in the composer.

  + Font sizes throughout the app have been made slightly smaller to match platform
   conventions. Like it the old way? Use the zoom feature in Workspace preferences!

  + The N1 icon is now more of a "sea foam" green, which helps it stand out among
    standard system icons, and features a square design on Windows.

  + Tons and tons of additional polish.

- Developer:

  + A new `MetadataStore` and `model.pluginMetadata` concept allows plugins to associate
    arbitrary data with threads and messages (like snooze times and link IDs).

- Many, many other bug fixes were incorporated into this release. Take a look at
  closed GitHub issues that made it into this release here:

  https://github.com/nylas/N1/issues?q=updated%3A2016-02-07..2016-02-25+is%3Aclosed


### 0.4.5 (2/7/16)

 + Resolves a critical issue where emails could not be sent from some aliases.
 + Fixes the keyboard shortcuts for "Go to All Mail", "Go to Starred", etc.

### 0.4.4 (2/5/16)

We're really excited to announce this release - the largest improvement to N1
since the initial release in October!

- Features:
 + Unified Inbox: The conversation view has been rebuilt so you can read and
   triage mail from all your accounts at once. In addition to the Inbox, we've
   unified Search, Drafts, Sent, Trash, and more.

 + Send and Archive: You can now choose Send and Archive when replying to threads.
   More "Send variants" are coming soon, including Send Later and Undo Send, and
   you can choose a default in Preferences.

 + Account Sidebar: We've rebuilt the account sidebar to address your feedback:
   + Rename folders and labels by right clicking / double clicking
   + Re-order accounts from Preferences > Accounts
   + See unread counts for all accounts when viewing "All Accounts"
   + Collapse label and folder views

 + Send As: You can now choose which account or alias a new draft should be sent
   from, and choose a default account in Preferences > Sending.

 + Launch On System Start: N1 can now launch in the background via an option in Preferences.

 + Search: You can now archive / trash items in the search results view.

 + Contact autocompletion is now unified, uses dramatically less memory, and does
   not depend on the selected account

 + Outbox: N1 now keeps mail it isn't able to send in your Drafts folder, and
   sends when you reconnect to the internet.

- Performance:
 + The conversation list has been rebuilt using a brand new "live query"
   API that yields great performance and minimizes costly database queries.
 + The conversation list data source no longer requires an accurate item count,
   removing frequent and expensive count queries.

 - Development:
  + `AccountStore.current()` has been deprecated and replaced with the concept of
    "Mailbox Perspectives" which are views of mail data.
  + Developer > Toggle Screenshot Mode now allows you to hide text in the app to
    take a screenshot.
  + `window.eval` has been disabled in N1. (Issue #1159)

- Fixes:
  + On Mac OS X, N1 no longer crashes when you change language or spellcheck preferences.
  + When viewing all accounts, the tray icon and dock icon also display
    the unified unread count.
  + You can now make N1 the default mail client on Windows.
  + You can now re-order mail rules and use "starred" as a rule criteria.
  + You can now authenticate IMAP / SMTP accounts where the username is not the
    email address. (Fixed in the Nylas Sync Engine.)
  + The maximum width of the account list has been increased.
  + And many, many, many other fixes!

- Coming Soon:
  + Our PR has landed in Electron, unblocking Swipe to Archive.

### 0.3.45 (1/21/16)

- Fixes:
 + The blue "Help" button in the app is smaller and goes to support.nylas.com.
   Thanks to everyone who sent in feedback via Intercom. We'd still love to
   hear from you on the community Slack channel!
 + When linking new accounts, there is more validation on the form fields
 + The newsletter checkbox now works properly when switching accounts.
 + The "Welcome" template in the QuickSchedule package has been updated.
 + N1 no longer generates errors installing on Ubuntu 14 and 15.
 + AM/PM capitalization has been standardized.
 + You can no longer accidentally select message timestamps.
 + We've increased the timeout for Exchange authentication, because it can
   actually take more than 30s to do Exchange AutoDiscovery.

### 0.3.43 (1/12/16)

- Features:
 + You can now enable and disable bundled plugins from Preferences > Plugins,
   and bundled plugin updates are delivered alongside N1 updates.
 + You can now adjust the interface zoom from the workspace preferences.

- Development:
 + Packages can now list a relative `icon` path in their package.json.

- Composer Improvements:
  + You can now reply inline by outdenting (pressing delete) in quoted text.
  + The Apple Mail keyboard shortcut for send is now correct.
  + Keyboard shortcuts are shown in the shortcuts preferences.
  + Clicking beneath the message body now positions your cursor correctly.
  + Tabbing to the body positions the cursor at the end of the draft reliably.
  + Tabbing to the subject highlights it correctly.
  + Copy & paste now preserves line breaks reliably
  + Inserting a template into a draft will no longer remove your signature.

- Fixes:
 + You can now unsubscribe from the N1 mailing list from the Account preferences.
 + The message actions dropdown is now left aligned.
 + Thread "Quick Actions" are now displayed in the correct order.
 + Account names can no longer overflow the preferences sidebar.
 + On Windows, N1 restarts after installing an update.
 + N1 now re-opens in fullscreen mode if it exited in fullscreen mode.
 + Files with illegal filesystem characters can be dragged and dropped normally.
 + Files with illegal filesystem characters now download and open correctly.
 + The Event RSVP interface only appears if you are a participant on the event.


### 0.3.36 (1/5/16)

- Features:
  + Mail Rules: Create mail rules from the preferences that sort incoming mail.
    You can also apply mail rules to your existing mail.
  + Templates: The templates example plugin now includes a robust template editor,
    better field jumping support, and many other improvements, and is now in ES6.
  + Column Widths: The app now saves the state of columns between sessions.
  + Mark As Read: You can now disable automatic "mark as read" behavior.

- Development:
  + Composer extensions have been overhauled to provide a better interface for developers.
    For more details, ping @evan or @juan on Slack, or see the new Templates extension.
  + Database transactions are now explicit and required for writing to the local cache.
  + The quick actions area of the thread list is now an injectable region.
  + You can now select the output of the test runner window.
  + Travis now builds both 64-bit .rpm and .deb builds for Linux.

- Fixes:
  + Opening the feedback window no longer prevents the app from quitting.
  + The QuickSchedule plugin can no longer send before saving the QuickSchedule event.
  + Switching accounts while searching no longer throws off the account switcher.
  + Emails sent from an alias now properly appear as "Me"
  + Web fonts from remote servers are now permitted in message bodies.
  + On Mac OS X and Linux, the system tray now includes an "Open Inbox" option
  + On Mac OS X, the app closes correctly from fullscreen mode.
  + On Linux, windows display the correct app icon.
  + On Gnome Linux, the app now shows the correct icon.
  + Google Inbox is now available as a keyboard shortcut preset.
  + File uploads can be cancelled, even if you're offline.
  + Dragging image uploads no longer causes duplicate attachments.
  + Parsing of contacts with allowable special characters (eg: o'rielly@gmail.com) is more robust.
  + The autoload images feature detects images more reliably.
  + mailto:// parsing is more robust and supports poorly encoded body values.

### 0.3.32 (12/15/15)

- Features:
  + Aliases: You can now add aliases from the Accounts preferences tab and use them when composing messages!
  + Themes: From the General preferences tab you can now install custom themes via a dropdown picker.

- Fixes:
  + Selecting multiple threads and marking as read / unread works as expected.
  + When you send a draft, it is correctly removed from the draft list.
  + Preferences open to the General tab by default.
  + Spellcheck:
    - On Mac OS X and Windows 8+, spellcheck now offers suggestions in
      the system language.
    - On Linux and Windows <8, spellcheck no longer defaults to english
      when your language is unavailable.

### 0.3.29 (12/9/15)

- Features:
  + Print: You can now print threads via a button beside the subject line.
  + Shortcuts: The preferences now list all available keyboard shortcuts.
  + Templates: The templates example now adds a basic template editor to the app's preferences
  + Expand / Collapse Thread: A button beside the subject line allows you to expand / collapse the thread.
  + Delete vs Archive: A new option allows you to choose the behavior of the Delete & Backspace keys.
  + Backgrounding: On Windows and Linux, the app will run from the System Tray, even if you close the main window.

- Fixes:
  + Unread counts now work correctly on providers that delete threads.
  + Bold, underline, and italic keybindings have been fixed.
  + Mark as unread / Mark as important keybindings have been added.
  + Search queries with special characters and punctuation now work.
  + On OS X, the badge icon now respects the option in preferences.
  + On Windows, the app's menu now shows conditional menu items properly.
  + On Linux, the preferences note that `zenity` is required for desktop notifications.
  + Disabling "Autoload images" blocks images without file extensions correctly.
  + The spellchecker now respects your system language preferences.
  + "Toggle unread" displays the correct icon when multiple emails are selected.
  + "Show Important flags" now works as expected for Gmail accounts.
  + Changing accounts with an active search query runs the query for the other account.
  + The up / down arrows in the thread pane now correctly move between threads.
  + Focus no longer jumps between composer fields when you type after clicking them.
  + The entire signature box is now clickable.

- Style:
  + The Translate and Quick Schedule plugins now have composer toolbar icons.
  + The undo/redo notification is styled correctly in dark mode.

- Development:
  + `DraftStoreExtension` and `MessageStoreExtension` have been deprecated in favor of `ComposerExtension` and `MessageViewExtension`, respectively. See 9f309d399b7fe01230b53d3dec994b372bf2fd54 for more details.
  + `nylas-exports` is available on the Developer Tools console as `$n`
  + New integration tests for the composer can be run with `script/grunt run-integration-tests`


### 0.3.27 (12/3/15)

- Critical patch to the QuickSchedule plugin to prevent it from sending multiple RSVP responses

### 0.3.26 (11/30/15)

- Features:
  + Link Targets: Hovering over links in an email displays their web address.
  + Signatures: In Preferences > Signatures, you can now configure a signature for each account.
    More signatures improvements are coming soon!
  + Quick RSVP: N1 displays an event summary with RSVP options for messages with calendar invites.

- Development:
  + The specs run correctly on Node v0.10, resolving issues with the Linux CI server

- Fixes:
  + On OS X, N1 no longer crashes when clicking the dock icon if the main window is hidden.
  + On Linux, N1 now handles retina displays correctly. No more tiny, tiny text!
  + The main window is focused when you open Preferences
  + On Fedora, N1 now appears with the correct icon
  + Remaining references to `app.terminate` replaced with `app.quit`

### 0.3.25 (11/25/15)

- Features:
  + Labels / Folders: You can now add labels from the sidebar and delete them by right-clicking.
  + Unread Counts: You can now turn on unread counts for all folders and labels in preferences
  + Examples: QuickSchedule allows you to easily send your availability and schedule events.
  + Status Bar Icon: On Mac OS X, the status bar icon is retina and renders properly in dark mode.
  + Preferences: The Preferences interface has been revamped in preparation for filters, signatures, and per-plugin preferences.

- Development:
  + We now use Electron `0.35.1`
  + We now use Spectron to run a few integration tests on Mac
  + The `atom` global has been renamed `NylasEnv`
  + The spec suite now runs and all tests pass on Linux (@mbilker)
  + The build process now supports Node 4.2 and Node 5
  + The build process exits if script/bootstrap fails

- Fixes:
  + The account switcher no longer sticks when trying to change accounts.
  + The app will no longer attempt to preview images larger than 5MB.
  + An outdated draft body no longer appears briefly when drafts are sent.
  + You can now right-click and paste images as well as text into the composer
  + `pre` tags in message bodies now render properly
  + `NYLAS_HOME` is defined in the renderer process on Linux (@mbilker)
  + The `MessageBodyProcessor` runs for every message, even if bodies are identical (@mbilker)
  + The collapsed state of labels in the sidebar is preserved through restart.
  + Choosing a subject line from the search suggestions now searches for that subject.

- Style:
  + Message rendering in dark mode is much better - no more white email backgrounds.
  + We now refer to "list view" and "split view" as "single panel" and "two panel"
  + The pop-out composer renders correctly in dark mode.

- Performance:
  + Queries for the thread list are now 4x faster thanks to revised join table indices.
  + Unread counts no longer require periodic `SELECT COUNT(*)` queries.
  + We've pulled Atom's new compile-cache, which provides speed improvements at launch.


### 0.3.23 (11/17/15)

- Features:
  + System Tray: Quickly create new messages, view unread count, and quit N1
  + Keybindings: The Gmail keybinding set now supports all Gmail shortcuts
  + Quick Account Switching: Use Cmd-1, Cmd-2, etc. to switch accounts
  + ES6 JavaScript: You can now write N1 plugins using ES6 (Stage 0) JavaScript
    - The "Quick Replies" example plugin is now written in ES6

- Fixes:
  + Mailto links with newline characters are now supported
  + File uploads no longer time out after 15 seconds
  + Label names are no longer autocapitalized
  + On Windows, the icon is no longer pixelated at many resolutions
  + On Windows, long paths no longer cause installation to fail
  + On Windows, N1 uses the "NylasPro" font correctly
  + Mark as read now works when viewing messages in two panel mode
  + Basic cut, copy, and paste menus are available for all inputs
  + You can now type in the middle of a search query
  + Names containing "via" are no longer truncated
  + N1 quits without throwing exceptions

- Internationalization:
  + Composition events are now supported in the composer
  + Labels with foreign characters no longer sync incorrectly in new accounts

- Style:
  + Dark mode looks better and has fewer color issues
  + Unread counts in the sidebar are smaller
  + Subject and body always align in the narrow thread list
  + The search box no longer overflows if you type a long search query
  + Hover states in menus and dropdowns are more consistent

- Performance:
  + In two panel mode, moving through messages quickly no longer causes jank.
  + Model.fromJSON is 40% faster thanks to optimized loops and other fixes
  + Models are lazily deserialized after being broadcast into other windows


### 0.3.20 (10/28/15)

- The “Update is Available” notification now links to release notes
- Notifications have improved styling, and the entire notification bar is clickable
- A new notification after updating links you to the release notes
- The search input has the correct X, and a better focus outline
- On Mac OS X, the green window frame dot is tied to fullscreen and changes to maximize when you hold option. (FINE.)
- On Windows, long paths no longer cause installation to fail (still in testing)
- Format checks prevent users from submitting crazy invite code strings to invite.nylas.com
- The invite code check now requests /status/, not /status, which prevents issues for some users
- The sidebar “hidden” setting is now persisted through relaunch

### 0.3.19 (10/23/15)

- Gmail users now have the option to “Move to Trash” in addition to "Archive", and we support the `#` Gmail shortcut.
- The sidebar now supports hierarchical labels/folders and sorts better
- Exchange auth includes an optional server field
- Windows
  + The onboarding screens no longer appear offscreen
  + Installing packages now works reliably
  + Styling is greatly improved and feels more native (toolbars, preferences)
  + The app no longer collides with Atom
- Mac OS X
  + Exiting fullscreen mode by closing the main window works as expected
- An error is displayed when uploading >25MB files
- Email TLDs more than 4 characters no longer result in an error
- The links in the Feedback window work
- A failing “save draft” action will stop the subsequent “send”, (failures cancel downstream tasks)
- The empty state animation eases with subpixel precision
- Atomic database queries no longer leak memory
- The chevron on Accounts is now flipped
- The draft list in the app is more robust, deleting drafts from the list view works
- Toolbar items no longer jump around when opening side panels
- We now use system tooltips instead of our HTML-based ones, so they look appropriate on all platforms

### 0.3.17

- Initial public release
