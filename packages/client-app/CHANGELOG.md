# Nylas Mail Changelog

### 1.0.28 (2/16/2017)

- Fixes:

  + Fix offline notification bug that caused outage!
  + Cloud api fixes for outage!
  + We now properly handle gmail auth token errors in the middle of the sync loop. This means less red boxes for users!
  + Less battery usage when initial sync has completed!
  + No more errors when saving sent messages to sent folders (`auth or accountId` errors)
  + No more `Lingering tasks in progress marked as failed errors`
  + Syncback tasks will continue retrying even after closing app
  + Syncback tasks retry more aggressively
  + Detect more offline errors when sending, sending is more reliable
  + Imap connection pooling (yet to land)
  + More retryable IMAP errors, means less red boxes for users
  + Offline notification now shows itself when we’re actually offline, shows countdown for next reconnect attempt

- Development:

  + More tests
  + Don't use breadcrumbs in dev mode
  + Add a better reason when waking sync for syncback in the logs
  + BackoffScheduler, BatteryManager added for reusability

### 1.0.27 (2/14/17)

- Fixes:

  + Offline notification fixes

### 1.0.26 (2/10/17)

- Fixes:

  + Downloads retry if they fail
  + NylasID doesn't intermittently log out or throw errors
  + Fix initial sync for Inbox Zero Gmail accounts

### 1.0.25 (2/10/17)

- Fixes:

  + When replying to a thread, properly add it to the sent folder

- Development:

  + Can now once again run Nylas Mail test suite

### 1.0.24 (2/9/17)

- Fixes:

  + Fix error reporter when reporting an error without an identity (this would
    crash the app)

- Development:

  + Fix logging inside local-sync api requests
  + Stop reporting handled API errors to Sentry
  + Report thread-list perf metrics

### 1.0.23 (2/8/17)

- Fixes:

  + Fix emails occasionally being sent with an incomplete body (#3269)
  + Correctly thread messages together when open/link tracking is enabled
  + Fix `Mailbox does not exist` error for iCloud users (#3253)
  + When adding account, correctly remove whitespace from emails
  + Fix link in update notification to point to latest changelog

- Performance:

  + Thread list actions no longer sporadically lag for ~1sec (this is especially
    noticeable when many accounts have been added)
  + No longer slow down sync process when more than 100,000 threads have been synced

- Development:

  + Better logging in worker window
  + You can now run a development build of Nylas Mail alongside a production
    build

### 1.0.22 (2/7/17)

- Fixes:

  + New mail notification sounds on startup are combined when multiple new messages have arrived
  + You can now correctly select threads using `cmd` and `shift`
  + Improve message fetching by making sure we always fetch the most recent
    messages first.
  + Improve IMAP connection timeouts by incrementing the socket timeout (#3232)
  + When adding a Google account, make sure to show the Account Chooser

- Development:

  + Nylas Identity is no longer stored in config.json

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
