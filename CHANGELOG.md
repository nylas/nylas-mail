# N1 Changelog

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
    - The "Templates" example plugin is now written in ES6

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
