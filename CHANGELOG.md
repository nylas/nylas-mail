# Mailspring Changelog

### 1.0.7 (10/28/2017)

Fixes:

- The `Starred` and `Unread` views now correctly show threads with many starred/unread messages. (#100)

- The folder and label shortcuts are now separate and work properly for Gmail accounts. (#259 - thanks @casuallancelot)

- Mailspring no longer segfaults when it's unable to connect to your SMTP server during onboarding,
  and error messages no longer "destroy" the layout of the window.

- Mailspring no longer uses all memory on the computer in a rare scenario where your mail provider return an infinite range of message IDs. (#91)

- Mailspring can now be put in a verbose logging mode using `AppEnv.mailsyncBridge.toggleVerboseLogging()`, in which all IMAP and SMTP traffic is logged.

- You can now dismiss the "Please pay for Mailspring Pro!" prompt in the bottom left when more than four accounts are syncing. (Thanks @mattlyons0)

- On Linux, Mailspring no longer launches with the onboarding window in between monitors on dual-display setups. (Thanks @dbhowell)

- The contact search index now includes the first names of contacts, so you can find them more easily when typing in address fields. (#227)

- The default template no longer references Nylas incorrectly. (Thanks @Galaxias)
 
### 1.0.6 (10/19/2017)

Features:

- Mailspring now identifies an "Archive" folder if one is present in your Office 365 / IMAP accounts and enables the "Archive" button and "Swipe to Archive" behavior. If it is not picked up automatically, you can set it from Preferences > Folders.

- Mailspring now warns you if you the salutation in your email ("Hey Ben!") doesn't match the name of a recipient or appears misspelled.

- A new keyboard shortcut allows you to attach a file in the composer. (Ctrl-Shift-A by default!)

Fixes:

- The contact sidebar now loads correctly if you switch to a contact with no name.

- On Windows, Mailspring no longer needs to be restarted once before you can link a Gmail account.

- When replying to a message you sent in a thread, Mailspring no longer incorrectly addresses the new message to yourself.

- Mail rules now run correctly as new mail is received.

- The label picker is now correctly hidden if your selection includes threads from non-Gmail accounts.

- When you forward a message, it is now correctly associated with the existing thread.

- When renaming folders / labels, the app no longer shows the old and new items side-by-side in the left panel for a few minutes.

- When creating folders / labels, you can now use any characters supported by your provider, including emoji.

- When you move an item to a folder in a generic IMAP account, undoing the action now works properly.


### 1.0.5 (10/15/2017)

Features:

- A new bar appears when you view the Trash and Spam folders allowing you to permanently delete messages.

Fixes:

- On Windows, Mailspring now uses the system font, which looks more crisp on Windows 10.

- On Windows, swipe to archive now works on touch-screen laptops.

- On Windows, we now ship the VS C++ Redistributable runtime, fixing issues many users had running the app after a fresh install.

- The default Chomium "double-tap-to-zoom" behavior has been disabled on all platforms.

- Preferences > Folders now shows UTF8 folder titles correctly.

- On OpenSUSE, Mailspring now looks for certificates at the correct path, fixing authentication issues with servers that use SSL.

- The undo/redo toast no longer appears when switching to Drafts and back.


### 1.0.4 (10/12/2017)

Features:

- Company profiles are now available in the right sidebar! See tons of great information about the people you're emailing, including their local time zone, the company's core business area, and more.

- You can now choose folder associations explicitly if Mailspring is unable to correctly identify your Sent folder, for example.

- The IMAP/SMTP authentication panel automatically defaults to security settings that match the ports you provide.

Fixes:

- Sending mail is considerably faster for accounts that do not place the message in the Sent folder automatically.

- Sent mail no longer appears to be from `Dec 31st 1969` when sent through some older SMTP gateways.

- New folders / labels appear faster after you create them, and adding folders now works properly on IMAP servers that use a namespace prefix like `INBOX.`.

- Improves display of "Identity is missing required fields" error and directs people to a knowledge base article.

- Localhost is an allowed IMAP/SMTP server address.

- `<object>` tags are now completely blocked in message bodies.

### 1.0.3 (10/10/2017)

Features:

- You can now choose custom IMAP and SMTP ports when linking a custom email account.

- You can now leave the SMTP username and password blank to connect to an SMTP gateway that does not require authentication.

Fixes:

- On Linux, Mailspring looks for your trusted SSL certificate roots in more locations, fixing the "Certificate Errors" many Fedora and ArchLinux users were seeing when linking accounts.

- On Linux, Mailspring bundles SASL2 and SASL2 plugins, resolving "Authentication Error" messages that users of non-Debian Linux distros saw when the local installation of SASL2 was an incompatible version.

- On Linux, Mailspring now links against libsecret, resolving intermittent "Identity missing required fields" errors that were caused by the Node bindings to libgnome-keyring's API.

- On Linux, composer and thread windows no longer have a "double window bar".

- On Linux, window menu bars no longer hide until you press the Alt key.

- The .rpm package now requires `libXss`, resolving installation issues for some users.

- Spellchecking on linux now works reliably.

- On Mac OS X, some menu shortcuts (like Command-H) now appear in the menu bar properly.

- Mailspring now correctly parses `mailto:` links with multiple semicolon-separated CC and BCC addresses.

- The "Raw HTML" signature editor is now the proper size.

### 1.0.2 (10/6/2017)

Fixes:

- During authentication, you can now view a "Raw Log" of the IMAP and SMTP communication with your servers for easy debugging of connection issues.

- During authentication, Mailspring will warn you if you connect Gmail via IMAP.

- The "Install Theme...", "Install a Plugin Manually..." and "Create a Plugin..." menu items now work. Note that Nylas Mail / N1 themes require some modifications to work with Mailspring!

- On Windows and Linux, Mailspring can now make itself the default mail client.

- The contact sidebar in the app now works reliably and is rate-limited for free users (The Clearbit API is very expensive!)

- On Windows, Mailspring now displays emails with encoded subject lines (often containing emoji or foreign characters) correctly.

- On Windows, you can now resize and maximize the Mailspring window.

- Mailspring now skips folders it can't sync rather than stopping the entire account.

### 1.0.1 (10/4/2017)

Fixes:

- On Linux, Mailspring now syncs mail reliably thanks to fixed builds of curl and mailcore2.

- On Windows, the app's icon now includes all the required resolutions.

- Many other minor fixes and sync improvements.

### 1.0.0 (10/3/2017)

Features:

- Entirely re-written sync engine uses significantly less RAM and CPU, improving performance and battery life.

- Mailspring launches 55% faster, thanks to a new package manager and theme manager and a thinner application bundle.

- Improved quoted text detection makes it easier to read threads, especially messages sent from Exchange and older versions of Outlook.

Developer:

- Mailspring now stores user preferences in the appropriate platform-specific location: `Library/Application Support` on the Mac, `AppData/Roaming` on Windows, etc.

- `NylasEnv` is now known as `AppEnv` and `nylas-exports` and `nylas-component-kit` have been renamed `mailspring-*`. Additionally, packages need to specify `"engines": {"mailspring":"*"}` instead of listing `nylas`.

- Much more of Mailspring has been converted to ES2016, and CoffeeScript is no longer supported for plugin development. The CoffeeScript interpreter will be removed in a future version. Please use ES2016 JavaScript instead.

- Mailspring now uses `Prettier` — before submitting pull requests, ensure `npm run lint` is clean, or add a Prettier plugin to your text editor. (It's awesome!)

- A plugin browser / "store" is coming soon - stay tuned!

Privacy:

- Mailspring does not send your email credentials to the cloud. Features like Snooze, Send Later, and Send Reminders now run on your computer. Future versions may re-introduce the option to run these features in the cloud.
