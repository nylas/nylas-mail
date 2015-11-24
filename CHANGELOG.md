# N1 Changelog

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
