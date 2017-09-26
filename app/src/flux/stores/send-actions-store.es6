import _str from 'underscore.string';
import NylasStore from 'nylas-store';
import Actions from '../actions';
import SendDraftTask from '../tasks/send-draft-task';
import * as ExtensionRegistry from '../../registries/extension-registry';

const ACTION_CONFIG_KEY = 'core.sending.defaultSendType';
const DefaultSendActionKey = 'send';
const DefaultSendAction = {
  title: 'Send',
  iconUrl: null,
  configKey: DefaultSendActionKey,
  isAvailableForDraft: () => true,
  performSendAction: ({ draft }) => Actions.queueTask(new SendDraftTask({ draft })),
};

function verifySendAction(sendAction = {}, extension = {}) {
  const { name } = extension;
  if (typeof sendAction.title !== 'string') {
    throw new Error(`${name}.sendActions must return objects containing a string "title"`);
  }
  if (!(sendAction.performSendAction instanceof Function)) {
    throw new Error(
      `${name}.sendActions must return objects containing an "performSendAction" function that will be called when the action is selected`
    );
  }
  return true;
}

class SendActionsStore extends NylasStore {
  constructor() {
    super();
    this._sendActions = [];
    this._onComposerExtensionsChanged();
    this._unsubscribers = [ExtensionRegistry.Composer.listen(this._onComposerExtensionsChanged)];
  }

  get DefaultSendActionKey() {
    return DefaultSendActionKey;
  }

  get DefaultSendAction() {
    return DefaultSendAction;
  }

  getSendActions() {
    return this._sendActions;
  }

  collectSendActions() {
    const all = [DefaultSendAction];
    for (const ext of ExtensionRegistry.Composer.extensions()) {
      const extActions = (ext.sendActions && ext.sendActions()) || [];
      for (const extAction of extActions) {
        try {
          verifySendAction(extAction, ext);
          extAction.configKey = _str.dasherize(extAction.title.toLowerCase());
          all.push(extAction);
        } catch (err) {
          NylasEnv.reportError(err);
        }
      }
    }
    return all;
  }

  sendActionForKey(configKey) {
    return this._sendActions.find(a => a.configKey === configKey);
  }

  availableSendActionsForDraft(draft) {
    return this._sendActions.filter(sendAction => sendAction.isAvailableForDraft({ draft }));
  }

  orderedSendActionsForDraft(draft) {
    const configKeys = this._sendActions.map(({ configKey } = {}) => configKey);

    let preferredKey = NylasEnv.config.get(ACTION_CONFIG_KEY);
    if (!preferredKey || !configKeys.includes(preferredKey)) {
      preferredKey = DefaultSendActionKey;
    }

    let preferred = this._sendActions.find(a => a.configKey === preferredKey);
    if (!preferred || !preferred.isAvailableForDraft({ draft })) {
      preferred = DefaultSendAction;
    }
    const rest = this._sendActions.filter(
      action => action !== preferred && action.isAvailableForDraft({ draft })
    );

    return { preferred, rest };
  }

  _onComposerExtensionsChanged = () => {
    this._sendActions = this.collectSendActions();
    this.trigger();
  };
}

export default new SendActionsStore();
