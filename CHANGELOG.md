# Nylas Mail Changelog

### 1.0.14 (1/25/17)

- Features:

  + Improved spellchecker

- Fixes:

  + Correctly update attributes like starred and unread when syncing folders.
    Marking as read or starred will no longer bounce back.

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
