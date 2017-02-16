import {Message, SendActionsStore, ExtensionRegistry} from 'nylas-exports'


const SendAction1 = {
  title: "Send Action 1",
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const SendAction2 = {
  title: "Send Action 2",
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const SendAction3 = {
  title: "Send Action 3",
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const NoTitleAction = {
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const NoPerformAction = {
  title: "No Perform",
  isAvailableForDraft: () => true,
}

const NotAvailableAction = {
  title: "Not Available",
  isAvailableForDraft: () => false,
  performSendAction: () => {},
}

const GoodExtension = {
  name: 'GoodExtension',
  sendActions() {
    return [SendAction1]
  },
}

const BadExtension = {
  name: 'BadExtension',
  sendActions() {
    return [null]
  },
}

const NoTitleExtension = {
  name: 'NoTitleExtension',
  sendActions() {
    return [NoTitleAction]
  },
}

const NoPerformExtension = {
  name: 'NoPerformExtension',
  sendActions() {
    return [NoPerformAction]
  },
}

const NotAvailableExtension = {
  name: 'NotAvailableExtension',
  sendActions() {
    return [NotAvailableAction]
  },
}

const NullExtension = {
  name: 'NullExtension',
  sendActions() {
    return null
  },
}

const OtherExtension = {
  name: 'OtherExtension',
  sendActions() {
    return [SendAction2, SendAction3]
  },
}

const {DefaultSendActionKey} = SendActionsStore

function sendActionKeys() {
  return SendActionsStore.sendActions().map(({configKey}) => configKey)
}

describe('SendActionsStore', function describeBlock() {
  beforeEach(() => {
    this.clientId = "client-23"
    this.draft = new Message({clientId: this.clientId, draft: true})
    spyOn(NylasEnv, 'reportError')
  });

  describe('sendActions', () => {
    it("returns default action when no extensions registered", () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey])
    });

    it('returns correct send actions', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, OtherExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1', 'send-action-2', 'send-action-3'])
    });

    it('handles extensions that return null for `sendActions`', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NullExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1'])
    });

    it('handles extensions that return null actions', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, BadExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1'])
    });

    it('omits and reports when action is missing a title', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NoTitleExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1'])
      expect(NylasEnv.reportError).toHaveBeenCalled()
    });

    it('omits reports when action is missing performSendAction', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NoPerformExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1'])
      expect(NylasEnv.reportError).toHaveBeenCalled()
    });

    it('includes not available actions', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NotAvailableExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      expect(sendActionKeys()).toEqual([DefaultSendActionKey, 'send-action-1', 'not-available'])
    });
  });

  describe('availableSendActionsForDraft', () => {
    it('excludes not available actions', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NotAvailableExtension]);
      SendActionsStore._onComposerExtensionsChanged()
      const actions = SendActionsStore.availableSendActionsForDraft()
      expect(actions.map(({configKey}) => configKey)).toEqual([DefaultSendActionKey, 'send-action-1'])
    });
  });

  describe('orderedSendActionsForDraft', () => {
    it("returns default action when no extensions registered", () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([]);
      SendActionsStore._onComposerExtensionsChanged()
      const {preferred, rest} = SendActionsStore.orderedSendActionsForDraft()
      expect(preferred.configKey).toBe(DefaultSendActionKey)
      expect(rest).toEqual([])
    });

    it('returns actions in correct grouping', () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, OtherExtension, NotAvailableExtension]);
      spyOn(NylasEnv.config, 'get').andReturn('send-action-1');
      SendActionsStore._onComposerExtensionsChanged()
      const {preferred, rest} = SendActionsStore.orderedSendActionsForDraft()
      const restKeys = rest.map(({configKey}) => configKey)
      expect(preferred.configKey).toBe('send-action-1')
      expect(restKeys).toEqual([DefaultSendActionKey, 'send-action-2', 'send-action-3'])
    });

    it("falls back to a default if value in config not present", () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, OtherExtension]);
      spyOn(NylasEnv.config, 'get').andReturn(null);
      SendActionsStore._onComposerExtensionsChanged()
      const {preferred} = SendActionsStore.orderedSendActionsForDraft()
      expect(preferred.configKey).toBe(DefaultSendActionKey)
    });

    it("falls back to a default if the primary item can't be found", () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, OtherExtension]);
      spyOn(NylasEnv.config, 'get').andReturn('does-not-exist');
      SendActionsStore._onComposerExtensionsChanged()
      const {preferred} = SendActionsStore.orderedSendActionsForDraft()
      expect(preferred.configKey).toBe(DefaultSendActionKey)
    });

    it("falls back to a default if the primary item is not available for draft", () => {
      spyOn(ExtensionRegistry.Composer, 'extensions').andReturn([GoodExtension, NotAvailableExtension]);
      spyOn(NylasEnv.config, 'get').andReturn('not-available');
      SendActionsStore._onComposerExtensionsChanged()
      const {preferred} = SendActionsStore.orderedSendActionsForDraft()
      expect(preferred.configKey).toBe(DefaultSendActionKey)
    });
  });

  // TODO Should go Task spec
  it("catches any errors in an extension performSendAction method", () => {

  });
});
