# Nylas Mail Changelog

### 1.0.21 (2/3/17)

- Fixes:

  + Fixed an issue where Nylas Mail could delete all accounts (addresses #3231)
  + Correctly delete and archive threads when they contain sent messages (addresses #2706)
  + Improve performance and prevent crashes when running several sync actions
  + Improve error handling when sync actions fail
  + Fix JSON serialization issue which could cause sync process to error.

### 1.0.20 (2/1/17)

- Fixes:

  + Properly clean up broken replies

### 1.0.19 (1/31/17)

- Fixes:

  + Replies on threads won't create duplicate-looking emails. This began
    to happen on midnight February 1 UTC due to a date parsing bug
  + Improve error handling in sync
  + Better retrying of certain syncback actions

- Development:

  + Now using Electron 1.4.15

### 1.0.18 (1/30/17)

- Performance:

  + 60% reduction of CPU usage during initial sync due to optimizing
    unnecessary rendering

- Fixes:

  + New composer stays in "to" field when initially typing

- Development:

  + Better documentation for Nylas Mail SDKs
  + GitHub repository renamed from nylas/N1 to nylas/nylas-mail
  + `master` branch now has Nylas Mail (1.0.x)
  + `n1-pro` branch now has Nylas Pro (1.5.x)

### 1.0.17 (1/27/17)

- Fixes:

  + Fix send and archive: Can now archive after sending without errors
  + Local search now includes more thread results
  + Contact autocomplete in composer participant fields now includes more results

### 1.0.16 (1/27/17)

- Performance:

  + Improved typing performance in the composer, especially with
    misspelled words

- Fixes:

  + Nylas Mail plugins install properly
  + Fix undo and occasional archive & move tasks failing due to not having uids
  + Fix logging for auth
  + Properly clean up after file downloads
  + Properly recover from IMAP uid invalidity

### 1.0.15 (1/25/17)

- Features:

  + Improve CPU performance of idle windows

- Fixes:

  + Correctly detect initial battery status for throttling.
  + Correctly allow auth for Custom IMAP accounts only #3185

### 1.0.14 (1/25/17)

- Features:

  + Improved spellchecker

- Fixes:

  + Correctly update attributes like starred and unread when syncing folders.
    Marking as read or starred will no longer bounce back.
  + Correctly detect new mail while syncing Gmail inbox.

### 1.0.13 (1/25/17)

- Fixes:

  + Messages immediately appear in sent folder. No bouncing back.
  + Login more likely to succeed. Waits longer for IMAP
  + Doesn't allow invalid form submission
  + Correctly handles token refresh failing
  + Auto updater says "Nylas Mail" properly
  + Sync drafts correctly on Gmail

- Development:

  + Local sync account API deprecated
  + Silence noisy queries in the logs

### 1.0.12 (1/24/17)

- Features:

  + New 'Debug' sync button that opens up the console
  + Faster search
  + Message processing now throttles when on battery
  + Analytics for change mail tasks

- Fixes:

  + Archive, Mark as Unread, and Move to trash don't "bounce back"
  + Adding a new account is now smoother
  + Improved threading
  + Drafts are no longer in the inbox

### 1.0.11 (1/19/17)

- Features:

  + Nylas Mail's installer on Mac uses a DMG

- Fixes:

  + Fixed app being occasionally unresponsive
  + Decreased odds of failed logins (by bumping connection timeout value)
  + Sync erroring notification no longer tripped by timeouts

### 1.0.10 (1/19/17)

- Features:

  + "Contact Support" button now auto-fills information
  + Actions reach providers faster

- Fixes:

  + Show errors on the GMail auth screen
  + Show draft sending errors
  + Can now correctly search threads via `from:` and `to:`
  + Other error management improvements
  + The database will now be reset if malformed
  + Improve the offline notification

- Development:

  + Update Thread indexing
  + Add loadFromColumm option to Attribute

### 1.0.9 (1/17/17)

- Fixes:

  + All Fastmail domains now use the correct credentials
  + Offline notification more reliable
  + Fix error logging

### 1.0.8 (1/17/17)

- Introducing Nylas Mail Basic! Read more about it [here](https://blog.nylas.com/nylas-mail-is-now-free-8350d6a1044d)
