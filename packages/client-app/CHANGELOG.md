# Nylas Mail Changelog

### 2.0.24 (4/25/2017)

  + [client-app] Speed up sending per recipient
  + [client-app] Fix tracking when sending per recipient

### 2.0.23 (4/25/2017)

- Fixes:
  + Properly retry retryable errors in syncback tasks

### 2.0.21 (4/24/2017)

- Fixes:
  + Fix throwing errors inside Interruptible
  + Fix sending on Gmail with large attachments (caused by conflict with syncing
    sent folder)
  + Increment max size for attachments

### 2.0.20 (4/24/2017)

- Fixes:
  + Correctly pass connSettings to convertSmtpError
  + Fix attachment previews
  + Fix link editor jumping away from you in composer
  + Fix certificate error msg
  + Detect smtp cert errors and relax condition to detect them

### 2.0.19 (4/21/2017)

- Features:
  + Allow users to select custom folder mappings for Sent and Trash folders
  + Move messages out of db into compressed flat files for better space
    efficiency

- Performance:
  + 10x speed improvement for sending messages
  + Improve performance of all syncback tasks by 500ms

- Fixes:
  + Correctly cleanup orphaned messages during sync

- Development:
  + Refactor sending code and remove cruft
  + Fix the specs

### 2.0.18 (4/21/2017)

- Fixes:
  + Correctly track all auth errors & correlate to email
  + Add more IMAP provider settings from Mozilla's ISPDB
  + Allow bypassing of invalid certificates during authentication
  + Don't double report auth errors

### 2.0.17 (4/19/2017)

- Fixes:
  + Record auth error location to Mixpanel
  + Show proper auth error messages to users
  + Correctly identify more certificate errors
  + Fix offline notification behind proxies
  + Fix attachment filename encodings

- Development
  + Prevent from running daily when untracked files present in working dir
  + Fixup auth helpers

### 2.0.16 (4/18/2017)

- Fixes:
  + Better handling of startup errors
  + Fix occasional EPERM issues on boot on Windows
  + Reduce CPU limits for historical sync
  + Fix search parser to handle nested queries properly
  + Update copy that still referenced N1 to Nylas Mail

- Development:
  + Fix benchmark mode

### 2.0.15 (4/17/2017)

  + Correctly handle and inform users about database malformed errors that can
    occur both in main process and/or window processes

### 2.0.14 (4/14/2017)

- Fixes:
  + Prevent from adding duplicate accounts and sync workers due to account id changes
  + Correctly remove sync worker reference when destroying it
  + Correctly initialize SyncProcessManager with Identity
  + Fix contact ranking runtime error

### 2.0.13 (4/13/2017)

- Fixes:
  + Upload nupkg with correct name for win32 autoupdater to work
  + Correctly handle window.unhandledrejection events

### 2.0.12 (4/13/2017)

- Fixes:
  + Prevent NM from overwriting N1 binary on windows
  + Fix runtime error in sync process
  + Prevent old N1 config from getting wiped when installing Nylas Mail

- Development:
  + Remove useless docs

### 2.0.11 (4/12/2017)

- Fixes:
  + Dispose of mail listener connection before getting new one. This will
    prevent sync process from leaking Imap connections and getting stuck.
  + Fix performance regression when polling for gmail attribute changes
  + Don't double report unhandled rejections
  + Fix unhandled rejection handling (fix ipc parse error)
  + Fix regression when processing messages under a transaction
  + Rate limit database malformed error reports to sentry

### 2.0.10 (4/11/2017)

- Fixes:
  + Fix missing UID error when archiving threads after sending
  + Ensure all mail folder exists before trying to access it
  + Fix SyncbackMetadataTask dependency

- Development:
  + Don't report stuck sync processes to Sentry
  + MessageFactory -> MessageUtils, SendUtils -> ModelUtils

### 2.0.9 (4/11/2017)

- Features:
  + Re-add imap to the onboarding accounts page

- Fixes:
  + Correctly detect changes in labels, starred and unread for Gmail accounts
  + Fix delta streaming connection retries
  + Handle weird MIME edge case with @ symbol

- Performance:
  + Wrap message processing in transaction for better performance
  + Increase sqlite `page_size` and `cache_size`

- Cloud:
  + Improve performance of reminders worker
  + Add DataDog StatsD for heartbeats
  + Restart automatically on unhandeld rejections

- Development:
  + Add benchmark mode

### 2.0.8 (4/7/2017)

- Fixes:
  + Revamp SSL options during authentication to be able to properly auth against
    SMTP and prevent sending failures
  + Ensure IMAPConnnectionPool uses updated account credentials
  + Always fetch and update identity regardless of environment
  + Properly handle serialization errors for JSON columns in database

- Cloud:
  + Switch MySQL charset to utf8mb4
  + Add exponential backoff for cloud worker jobs when encountering errors
  + Use IMAP connection pool in cloud workers to limit number of connections
  + Properly generate metadata deltas when clearing expiration field
  + Increment default imap connection socket timeout in cloud workers

- Plugins:
  + Correctly syncback metadata for send later
  + Delete drafts after they are sent later
  + Correctly ensure messages in sent folder for send later in gmail
  + Fix send reminders version conflict error
  + Correctly set metadata values for send reminders
  + Fix imap folder names in send-reminders
  + Fix send later access token refresh

- Development:
  + Add view of CloudJobs in n1.nylas.com/admin
  + Ensure daily script grabs current version after pulling latest changes

### 2.0.1 (4/5/2017)

- Features:
  + Limit search to focused perspective

- Fixes:
  + IMAPConnectionPool now correctly disposes connections
  + Ensure we use refreshed access token for all imap connections during sync
  + Prevent IMAP connection leaking in sync worker
  + Fix send later button saving state and sending action
  + Fix inline images for send later
  + Correctly enable plugins on 2.0.1
  + Make sure app can update even after signing out of NylasID
  + Don't make any requests when NylasID isn't present

- Cloud:
  + Make cloud workers more robust
  + Remove old SignalFX reporter & add docs
  + Log errors according to bunyan specs

- Development:
  + Add script to run benchmarks once per day at specified time
  + Add script to upload benchmark data to Google Sheets
  + Add better logging when restarting stuck sync worker

### 2.0.0 (4/4/2017)

Introducing Nylas Mail Pro

- Features:
  + Enable snooze, send later, and send reminders
  + Add feature limits to reminders and send later

- Fixes
  + Don't assign duplicate folder roles
  + Re-setup IdentityStore in new window

- Development:
  + Fix sqlite build for older versions of clang
  + Remove rogue scripts-tmp folder
  + Remove unecessary db setup for mail rules

### 1.0.55 (3/31/2017)

- Fixes
  + Ensure open/link tracking work when sending multiple consecutive emails
  + Fix performance of contact rankings database query
  + Fix performance of thread search index database queries
  + Fix performance of ANALYZE queries

### 1.0.54 (3/31/2017)

- Features:
  + Add search support for `has:attachment`

- Fixes:
  + Reduce database thrashing caused by thread search indexing
  + Interrupt long-running syncback tasks
  + Fix performance of contact rankings db query
  + Don't hit contact rankings endpoint until account is ready
  + Ensure sync worker is stopped correctly when removing accounts or when
    restarting it

- Metrics:
  + Report metrics about SyncbackTask runs

- Perf:
  + Delay building new hot window to improve win perf

- Development:
  + Add script to benchmarks new commits
  + Add DEBUG flag to be able to log all query activity for both databases
  + Add `DatabaseStore.write` which doesn't use Transactions
  + Metadata test fixes

### 1.0.52 (3/29/2017)

- Fixes:
  + Fix open and link tracking:
    + No longer triggers your own opens & link clicks
    + Link tracking indicator is now always present in sent messages
  + Fix regression in DB query execution which would delay all queries in the
    system.
  + Reduce max retry backoff for DB queries, which could hold a query open for
    too long
  + Fix thread reindexing issues, which should help performance and correctly
    index threads for search
  + Fix `in:` search syntax for non-gmail search
  + Fix references to RetryableError imports

- Development:
  + Add initial sync benchmarking script
  + Clean up logging in DatabaseStore: differentiate background queries from
    regular queries in the logs, only log queries that actually take more than
    100ms.
  + Point the billing server URL to staging by default for easier development,
    and allow it to be overriden
  + Add index to expiration field on Metadata

### 1.0.51 (3/28/2017)

- Features:
  + Restore contact rankings feature for better contact predictions in composer
    recipient fields

- Fixes:
  + Correctly listen for new mail in between sync loops
  + Verify SMTP credentials in /auth endpoint
  + Also prioritize sent label for initial Gmail sync
  + Properly relaunch windows on autoupdate
  + Properly set up local /health endpoint by making sure to attach route files
    ending in .es6 to local-api

- Perf:
  + Don't throttle while syncing first 500 threads

- Metrics:
  + Report battery state changes to Mixpanel

- Development:
  + Make deploy-it say what it's doing instead of hanging silently
  + Make deploy-it print link to the EB console
  + Make help message better on deploy-it
  + Add `SHOW_HOT_WINDOW` env for prod debugging of window launches
  + Correctly ignore `node_modules` in .ebignore for faster deploys
  + Only bootstrap specific pkgs in postinstall for faster npm installs

### 1.0.50 (3/28/2017)

- Fixes:
  + Fix SyncActivity errors introduced in 1.0.49

### 1.0.49 (3/27/2017)

- Fixes:
  + Ensure sync process does not get stuck
  + Ensure the worker window is always available
  + Retry database operations when encountering locking issues

- Metrics:
  + Detect and report when the worker window is unavailable
  + Detect and report when a sync process is stuck

- Development:
  + Windows autoupdater fixes
  + Add better documentation for windows autoupdater
  + Remap windows dev shortcuts to match the ones used on darwin and linux
  + When building app, only re-install for optional dependencies on darwin

- Cloud:
  + Timeout streaming API connections every 15 minutes
  + Add missing database indexes from SQL review

### 1.0.48 (3/27/2017)

- Fixes:
  + Reindex threads when they're updated
  + Don't try to restart sync on every IdentityStore change
  + Correctly remove inline images with x button

### 1.0.47 (3/23/2017)

- Fixes:
  + Report hard crashes using Electron's built-in crash reporter

- Development:
  + Don't handle IMAP timeouts in the connection pool
  + Record file download times

### 1.0.46 (3/22/2017)

- Fixes:
  + Ensure files get transferred in forwarded messages
  + Correctly sign out of NylasID
  + Don't report non-reportable errors in delta connection
  + Fix S3 attachment upload for send later

- Development:
  + Rename downloadDataForFile(s) -> getDownloadDataForFile(s)
  + Switch type of Metadata value column
  + Fix build condition
  + Fix DraftFactory specs
  + Refactor sync worker IMAPConnectionPool callbacks

### 1.0.45 (3/21/2017)

- Fixes:
  + Correctly report unhandled errors caught in window.
  + Fix passing cursor to delta streams

### 1.0.44 (3/20/2017)

- Fixes:
  + Add error handling when creating syncback requests
  + Fix path for tmp dir in daily script

### 1.0.43 (3/17/2017)

- Fixes:

 + Revert nodemailer to previous version
 + Creating a folder no longer creates a non-existent duplicate subfolder
 + Don't bump threads to the top of list when a message is sent: only update lastReceivedDate if the message was actually received

### 1.0.42 (3/16/2017)

- Fixes:
 + Fix spellchecker regression (Don't exclude source maps in build)

### 1.0.41 (3/16/2017)

- Development:
  + Upgrade nodemailer to latest version

### 1.0.40 (3/15/2017)

- Features:
  + Add support for attachments in send later

- Development:
  + Improve build time
  + Windows Autoupdater fixes

### 1.0.39 (3/14/2017)

- Fixes:
  + Fix missing depedency for imap-provider-settings

- Development:
  + Only upload 7 characters of the commit hash for Windows build

### 1.0.38 (3/13/2017)

- Fixes:
 + Restart sync when computer awakes from sleep
 + Fix issue that made users log out of NylasID, restart, and then force them to log out and restart again in a loop (#3325)
 + Don't start sync or delta connections without an identity

- Development:
 + Restore windows build
 + Remove specs from production build
 + Fix arc lint
 + Specify Content-Type in developer bar curl commands

### 1.0.37 (3/10/2017)

- Fixes:
  + Fix regression introduced in 1.0.36 in the message processor
  + Correctly show auth error when we can't connect to n1cloud
  + Fix error thrown sometimes when handling send errors

### 1.0.36 (3/10/2017)

- Fixes:
  + Increase the IMAP connection pool size
  + Shim sequelize to timeout after 1 minute on every database operation. This
    is a safeguard to prevent unresolved db promises from halting the sync loop.
  + Better error handling to prevent the message processor from halting sync

- Development:
  + Measure and report inline composer open times
  + Refactor MessageProcessor to be more robust to errors

### 1.0.35 (3/9/2017)

- Fixes:
  + Make sure delta connection is restarted when an account is re-authed
  + More defensive error handling to prevent sync from halting
  + Prevent delta streaming connection from retrying too much
  + Fix error when attempting to report a fetch id error
  + Prevent  error restart loop when database is malformed
  + Correctly cancel search when the search perspective is cleared
  + When many search results are returned from the server, don't try to sync them all at once, otherwise would slow down the main sync process.
  + When restarting the app, don't try to continue syncing search results from an old search

- Development:
  + Consolidate delta connection stores, remove `internal_package/deltas`
  + Rename NylasSyncStatusStore to FolderSyncProgressStore
  + Consolidate APIError status code that we should not report
  + Don't report incorrect username or password to Sentry
  + Rate limit error reporting for message processing errors
  + Fix circular reference error when reporting errors
  + Refactor file download IMAPConnectionPool usage
  + Don't focus the Console tab in dev tools every time an error is logged
  + Correctly set process title

### 1.0.34 (3/8/2017)

- Fixes:
  + Sync should not get stuck anymore due to sequelize
  + Delta Streaming connections now correctly retry after they are closed or an error occurs
  + Handle errors when opening imap box correctly

- Development:
  + Add script/daily
  + Provide better info to Sentry on sending errors
  + Refactor and clean up delta streaming code
  + Refactor message processing throttling

### 1.0.33 (3/8/2017)

- Features:

  + Add intitial support for send later

- Fixes:

  + Fetch unknown message uids returned in search results
  + Don't throttle message processing when syncing specific UIDs

- Development:

  + Better grouping for APIError by URL also
  + Don't generate sourceMapCache in prod mode
  + Upload a next-version to S3 for autoupdate testing
  + Windows build fixes

### 1.0.32 (3/7/2017)

- Development:

  + Report provider when reporting remove-from-threads-from-list
  + Report provider when reporting send perf metrics

### 1.0.31 (3/6/2017)

- Fixes:

  + Improve initial sync speed by scaling number of messages synced based on
    folder SELECT duration
  + Immediately restore sync process when app comes back online after being
    disconnected from the internet.
  + Can now reply from within notifications again

- Development:

  + Add basic rate limiting to Sentry
  + Report all search performance metrics
  + Prevent noisy uncaught errors when closing long connection
  + Improve reporting of refresh access token errors
  + Don't double report refresh access token API errors
  + Replace `setImmediate` with `setTimeout` as Promise scheduler
  + Use new Bluebird preferred `longStackTraces` syntax
  + NylasAPIRequest refactored and cleaned up
  + Search refactors and improvements
  + Protect from operating on IMAP connection while opening a box
  + Enable logging in prod builds
  + Make deploy-it support -h/--help
  + Restore cloud testing environments

### 1.0.30 (2/28/2017)

- Fixes:

  + Can properly add signatures and select them as default for different
    accounts.
  + Can now correctly reply to a thread and immediately archive it or move it to
    another folder without throwing an error (#3290)
  + Correctly fix IMAP connection timeout issues (#3232)
  + Nylas Mail no longer opens an increasing number of IMAP connections which
    caused some users to reach IMAP server connection limits (#3228)
  + Fix memory leak while syncing which caused sync process to restart
    sometimes.
  + Correctly handle IMAP connections ending unexpectedly
  + Correctly detect retryable IMAP errors during sync + detect more
    retryable errors
  + Correctly catch more authentication errors when sending
  + Improve speed of processing messages during sync
  + Prevent unnecessary re-renders of the thread list

- Development:

  + Report performance metrics
  + More Coffeescript to Javascript conversions

### 1.0.29 (2/21/2017)

- Fixes:

  + You can now click inline images in messages to open them
  + More IMAP errors have been identified as retryable, which means users will
    see less errors when syncing an account
  + Improve performance of thread search indexing queries
  + Correctly catch Invalid Login errors when sending

- Development:

  + Developer bar in Worker window now shows single delta connection
  + More code converted to Javascript

### 1.0.28 (2/16/2017)

- Fixes:

  + Fix offline notification bug that caused api outage
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
