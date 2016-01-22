# N1 Changelog

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
