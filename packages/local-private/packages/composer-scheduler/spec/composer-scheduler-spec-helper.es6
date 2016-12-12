import {
  DatabaseStore,
  DraftStore,
  Message,
  Actions,
  Calendar,
  Contact,
} from 'nylas-exports'
import {activate, deactivate} from '../lib/main'
import {PLUGIN_ID} from '../lib/scheduler-constants'

export const DRAFT_CLIENT_ID = "draft-client-id"

export const testCalendars = () => [new Calendar({
  clientId: "client-1",
  servierId: "server-1",
  name: "Test Calendar",
})]

// Must be a `function` so `this` can be overridden by caller's `apply`
export const prepareDraft = function prepareDraft() {
  spyOn(NylasEnv, "isMainWindow").andReturn(true);
  spyOn(NylasEnv, "getWindowType").andReturn("root");
  spyOn(Actions, "setMetadata").andCallFake((draft, pluginId, metadata) => {
    if (!this.session) {
      throw new Error("Setup test session first")
    }
    this.session.changes.addPluginMetadata(PLUGIN_ID, metadata);
  })
  activate();

  const draft = new Message({
    clientId: DRAFT_CLIENT_ID,
    draft: true,
    body: "",
    accountId: window.TEST_ACCOUNT_ID,
    from: [new Contact({email: window.TEST_ACCOUNT_EMAIL})],
  })

  spyOn(DatabaseStore, "run").andCallFake((query) => {
    if (query.objectClass() === Calendar.name) {
      return Promise.resolve(testCalendars())
    } else if (query.objectClass() === Message.name) {
      return Promise.resolve(draft)
    }
    return Promise.resolve()
  })
  this.session = DraftStore._createSession(DRAFT_CLIENT_ID, draft);
}

export const cleanupDraft = function cleanupDraft() {
  DraftStore._cleanupAllSessions()
  deactivate()
}

export const setupCalendars = function setupCalendars() {
  const aid = window.TEST_ACCOUNT_ID
  spyOn(DatabaseStore, "findAll").andCallFake((klass, {accountId}) => {
    expect(klass).toBe(Calendar);
    expect(accountId).toBe(aid);
    const cals = [
      new Calendar({accountId: aid, readOnly: false, name: 'a'}),
      new Calendar({accountId: aid, readOnly: true, name: 'b'}),
    ]
    return Promise.resolve(cals);
  })
}
