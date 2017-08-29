import _ from 'underscore'
import NylasStore from 'nylas-store'
import {
  IdentityStore,
  Actions,
  AccountStore,
  FocusedPerspectiveStore,
  NylasAPIRequest,
} from 'nylas-exports'

import AnalyticsSink from '../analytics-electron'

/**
 * We wait 15 seconds to give the alias time to register before we send
 * any events.
 */
const DEBOUNCE_TIME = 5 * 1000;

class AnalyticsStore extends NylasStore {

  activate() {
    // Allow requests to be grouped together if they're fired back-to-back,
    // but generally report each event as it happens. This segment library
    // is intended for a server where the user doesn't quit...
    this.analytics = new AnalyticsSink("merani", {
      host: `${NylasAPIRequest.rootURLForServer('identity')}/api/s`,
      flushInterval: 500,
      flushAt: 5,
    })
    this.launchTime = Date.now();

    const identifySoon = _.debounce(this.identify, DEBOUNCE_TIME);
    identifySoon();

    // also ping the server every hour to make sure someone running
    // the app for days has up-to-date traits.
    setInterval(identifySoon, 60 * 60 * 1000); // 60 min

    this.listenTo(IdentityStore, identifySoon);
    this.listenTo(Actions.recordUserEvent, (eventName, eventArgs) => {
      this.track(eventName, eventArgs);
    })
  }

  // Properties applied to all events (only).
  eventState() {
    // Get a bit of context about the current perspective
    // so we can assess usage of unified inbox, etc.
    const perspective = FocusedPerspectiveStore.current();
    let currentProvider = null;

    if (perspective && perspective.accountIds.length > 1) {
      currentProvider = 'Unified';
    } else {
      // Warning: when you auth a new account there's a single moment where the account cannot be found
      const account = perspective ? AccountStore.accountForId(perspective.accountIds[0]) : AccountStore.accounts()[0];
      currentProvider = account && account.displayProvider();
    }

    return {
      currentProvider,
    };
  }

  // Properties applied to all events and all people during an identify.
  superTraits() {
    const theme = NylasEnv.themes ? NylasEnv.themes.getActiveTheme() : null;

    return {
      version: NylasEnv.getVersion().split("-")[0],
      platform: process.platform,
      activeTheme: theme ? theme.name : null,
      workspaceMode: NylasEnv.config.get("core.workspace.mode"),
    };
  }

  baseTraits() {
    return Object.assign({}, this.superTraits(), {
      firstDaySeen: this.firstDaySeen(),
      timeSinceLaunch: (Date.now() - this.launchTime) / 1000,
      accountCount: AccountStore.accounts().length,
      providers: AccountStore.accounts().map((a) => a.displayProvider()),
    });
  }

  personalTraits() {
    const identity = IdentityStore.identity();
    if (!(identity && identity.id)) { return {}; }

    return {
      email: identity.emailAddress,
      firstName: identity.firstName,
      lastName: identity.lastName,
    };
  }

  track(eventName, eventArgs = {}) {
    // if (NylasEnv.inDevMode()) { return }

    const identity = IdentityStore.identity()
    if (!(identity && identity.id)) { return; }

    this.analytics.track({
      event: eventName,
      userId: identity.id,
      properties: Object.assign({},
        eventArgs,
        this.eventState(),
        this.superTraits(),
      ),
    })
  }

  firstDaySeen() {
    let firstDaySeen = NylasEnv.config.get("firstDaySeen");
    if (!firstDaySeen) {
      const [y, m, d] = (new Date()).toISOString().split(/[-|T]/);
      firstDaySeen = `${m}/${d}/${y}`;
      NylasEnv.config.set("firstDaySeen", firstDaySeen);
    }
    return firstDaySeen;
  }

  identify = () => {
    if (!NylasEnv.isMainWindow()) {
      return;
    }

    const identity = IdentityStore.identity();
    if (!(identity && identity.id)) { return; }

    this.analytics.identify({
      userId: identity.id,
      traits: this.baseTraits(),
      integrations: {All: true},
    });

    // Ensure we never send PI anywhere but Mixpanel

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
