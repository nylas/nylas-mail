import _ from 'underscore'
import Segment from 'analytics-node' // eslint-disable-line
import NylasStore from 'nylas-store'
import crypto from 'crypto'
import {getMac} from 'getmac' // eslint-disable-line
import {MetricsReporter} from 'isomorphic-core' // eslint-disable-line
import {
  IdentityStore,
  Actions,
  AccountStore,
  FocusedPerspectiveStore,
} from 'nylas-exports'

/**
* We white list actions to track.
*
* The Key is the action and the value is the callback function for that
* action. That callback function should return the data we pass along to
* our analytics service based on the sending data.
*
* IMPORTANT: Be VERY careful about what private data we send to our
* analytics service!!
*
* Only completely anonymous data essential to future metrics or
* debugging may be sent.
*/

/**
 * We wait 15 seconds to give the alias time to register before we send
 * any events.
 */
const DEBOUNCE_TIME = 15 * 1000
const PERF_ACTIONS_TO_EVENTS_MAP = {
  'remove-threads-from-list': 'Perf: Removed Threads from List',
  'select-thread': 'Perf: Selected Thread',
  'send-draft': 'Perf: Draft Sent',
  'perform-local-task': 'Perf: Task Performed Database Operation',
  'open-composer-window': 'Perf: Composer Window Opened',
  'open-add-account-window': 'Perf: Add Account Window Opened',
  'app-boot': 'Perf: App Booted',
  'search-performed': 'Perf: Search Performed',
}

class AnalyticsStore extends NylasStore {

  activate() {
    // We have to flush every request every time otherwise the window could
    // close before we've sent the event. We're not really a "server"
    // handling hundreds of requests. We can flush every single time.
    this.analytics = new Segment("fVM35MqaTJ4M19kZnWbm3EelgTFnHtw2", {flushAt: 1})
    this.launchTime = Date.now()

    this.listenTo(AccountStore, _.debounce(this.identify, DEBOUNCE_TIME))
    this.listenTo(IdentityStore, _.debounce(this.identify, DEBOUNCE_TIME))

    this.coreActivePluginNames = []
    this.thirdPartyActivePluginNames = []
    this.listenTo(Actions.notifyPluginsChanged, _.debounce((pluginData = {}) => {
      this.coreActivePluginNames = pluginData.coreActivePluginNames || []
      this.thirdPartyActivePluginNames = pluginData.thirdPartyActivePluginNames || []
      this.identify()
    }, DEBOUNCE_TIME))

    setInterval(this.identify, 1 * 60 * 1000)

    this.deviceHash = "unknown"

    getMac((err, macAddress) => {
      if (!err && macAddress) {
        this.deviceHash = crypto.createHash('md5').update(macAddress).digest('hex')
      }
    })

    this.setupActionListeners()
  }


  // Properties applied to all events (only).
  superProperties() {
    // Get a bit of context about the current perspective
    const perspective = FocusedPerspectiveStore.current();
    let account = null
    let accountId = null;
    let accountType = null;

    if (perspective) {
      account = AccountStore.accountForId(perspective.accountIds[0]);
    }
    if (account == null) {
      account = AccountStore.accounts()[0];
    }

    if (account) {
      accountType = account.displayProvider();
      if (perspective && perspective.accountIds.length > 1) {
        accountType = 'Unified';
      }
      accountId = account.id;
    }

    return {
      currentAccountId: accountId,
      currentAccountProvider: accountType,
    };
  }

  // Properties applied to all events and all people during an identify.
  superTraits() {
    const theme = NylasEnv.themes ? NylasEnv.themes.getActiveTheme() : null;

    return {
      version: NylasEnv.getVersion().split("-")[0],
      platform: process.platform,
      inDevMode: NylasEnv.inDevMode(),
      deviceHash: this.deviceHash,
      activeTheme: theme ? theme.name : null,
      workspaceMode: NylasEnv.config.get("core.workspace.mode"),
      activePlugins: this.coreActivePluginNames,
      numActivePlugins: this.coreActivePluginNames.length,
    };
  }

  // Base traits for a person sent to all analytics services.
  baseTraits() {
    const providers = AccountStore.accounts().map((a) => a.displayProvider());
    return Object.assign({}, this.superTraits(), {
      providers: providers,
      accountIds: _.pluck(AccountStore.accounts(), "id"),
      numAccounts: AccountStore.accounts().length,
      usedDevMode: this.usedDevMode(),
      firstDaySeen: this.firstDaySeen(),
      timeSinceLaunch: (Date.now() - this.launchTime) / 1000,
      activeThirdPartyPlugins: this.thirdPartyActivePluginNames,
      numActiveThirdPartyPlugins: this.thirdPartyActivePluginNames.length,
    });
  }

  // Personal traits for a person sent to analytics services.
  personalTraits() {
    const identity = IdentityStore.identity();
    if (!(identity && identity.id)) { return {}; }

    return {
      email: identity.email,
      lastName: identity.lastname,
      firstName: identity.firstname,
      connectedEmails: _.pluck(AccountStore.accounts(), "emailAddress"),
    };
  }

  setupActionListeners() {
    this.listenTo(Actions.recordUserEvent, (eventName, eventArgs) => {
      this.track(eventName, eventArgs);
    })
    this.listenTo(Actions.recordPerfMetric, (data) => {
      this.recordPerfMetric(data)
    })
  }

  recordPerfMetric(data) {
    const {action, actionTimeMs} = data
    if (!action || actionTimeMs == null) {
      throw new Error('recordPerfMetric requires at least an `action` and `actionTimeMs`')
    }
    const identity = IdentityStore.identity()
    if (!identity) { return }
    const nylasId = identity.id

    const accounts = AccountStore.accounts()
    if (!accounts || accounts.length === 0) { return }

    // accountId is irrelevant for metrics reporting but we need to include
    // one in order to make a NylasAPIRequest to our /ingest-metrics endpoint
    const accountId = accounts[0].id
    const {maxValue = 3000, sample = 1, ...dataToReport} = data

    if (sample < 0 || sample > 1) {
      throw new Error('recordPerfMetric requires a `sample` size between 0 and 1')
    }

    // Just report <sample>% of metrics
    if (Math.random() >= sample) { return }

    // Report to honeycomb
    MetricsReporter.reportEvent(Object.assign({nylasId, accountId}, dataToReport))

    // When reporting to Mixpanel, we need to make sure time data is clipped
    // to a range so that reporting does not get screwed up
    const clippedActionTimeMs = Math.min(Math.max(0, actionTimeMs), maxValue)
    const eventName = PERF_ACTIONS_TO_EVENTS_MAP[action] || action
    this.track(eventName, Object.assign({}, dataToReport, {
      actionTimeMs: clippedActionTimeMs,
      rawActionTimeMs: actionTimeMs,
    }))
  }

  track(eventName, eventArgs = {}) {
    if (NylasEnv.inDevMode()) { return }
    const identity = IdentityStore.identity()
    if (!(identity && identity.id)) { return; }
    this.identify()

    this.analytics.track({
      event: eventName,
      userId: identity.id,
      properties: Object.assign({},
        eventArgs,
        this.superTraits(),
        this.superProperties(),
      ),
    })
  }

  firstDaySeen() {
    let firstDaySeen = NylasEnv.config.get("nylas.firstDaySeen");
    if (!firstDaySeen) {
      const [y, m, d] = (new Date()).toISOString().split(/[-|T]/);
      firstDaySeen = `${m}/${d}/${y}`;
      NylasEnv.config.set("nylas.firstDaySeen", firstDaySeen);
    }
    return firstDaySeen;
  }

  usedDevMode() {
    let usedDevMode = NylasEnv.config.get("nylas.usedDevMode");
    if (!usedDevMode) {
      usedDevMode = NylasEnv.inDevMode();
      NylasEnv.config.set("nylas.usedDevMode", usedDevMode);
    }
    return usedDevMode;
  }

  identify = () => {
    if (!NylasEnv.isWorkWindow()) {
      return;
    }

    const identity = IdentityStore.identity();
    if (!(identity && identity.id)) { return; }

    // It's against Google Analytics (and several other's) terms of
    // services to send personally-identifiable information. We send two
    // separate "Identify" calls. Once to GA and others. And a separate
    // one with personal data to Mixpanel.
    this.analytics.identify({
      userId: identity.id,
      traits: this.baseTraits(),
      integrations: {All: true},
    });

    this.analytics.identify({
      userId: identity.id,
      traits: Object.assign({}, this.baseTraits(), this.personalTraits()),
      integrations: {
        All: false,
        Mixpanel: true,
      },
    });
  }
}

export default new AnalyticsStore()
