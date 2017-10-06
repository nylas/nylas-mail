# Mailspring Changelog

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
