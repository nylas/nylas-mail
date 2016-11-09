import _ from 'underscore'
import _str from 'underscore.string'
import NylasStore from 'nylas-store'
import Actions from '../actions'
import SendDraftTask from '../tasks/send-draft-task';
import * as ExtensionRegistry from '../../registries/extension-registry';


const ACTION_CONFIG_KEY = "core.sending.defaultSendType";
const DefaultSendActionKey = 'send'
const DefaultSendAction = {
  title: "Send",
  iconUrl: null,
  configKey: DefaultSendActionKey,
  isAvailableForDraft: () => true,
  performSendAction: ({draft}) => Actions.queueTask(new SendDraftTask(draft.clientId)),
}

function verifySendAction(sendAction = {}, extension = {}) {
  const {name} = extension
  if (!_.isString(sendAction.title)) {
    throw new Error(`${name}.sendActions must return objects containing a string "title"`);
  }
  if (!_.isFunction(sendAction.performSendAction)) {
    throw new Error(`${name}.sendActions must return objects containing an "performSendAction" function that will be called when the action is selected`);
  }
  return true;
}

function configKeyFromTitle(title) {
  return _str.dasherize(title.toLowerCase());
}

function getSendActions() {
  return [DefaultSendAction].concat(
    ExtensionRegistry.Composer.extensions()
    .filter((extension) => extension.sendActions != null)
    .reduce((accum, extension) => {
      const sendActions = (extension.sendActions() || [])
      .filter((sendAction) => sendAction != null)
      .map((sendAction) => {
        try {
          verifySendAction(sendAction, extension);
          sendAction.configKey = configKeyFromTitle(sendAction.title);
          return sendAction
        } catch (err) {
          NylasEnv.reportError(err);
          return null
        }
      })
      .filter((sendAction) => sendAction != null)
      return accum.concat(sendActions)
    }, [])
  )
}

class SendActionsStore extends NylasStore {

  constructor() {
    super()
    this._sendActions = []
    this._onComposerExtensionsChanged()
    this._unsubscribers = [
      ExtensionRegistry.Composer.listen(this._onComposerExtensionsChanged),
    ]
  }

  get DefaultSendActionKey() {
    return DefaultSendActionKey
  }

  get DefaultSendAction() {
    return DefaultSendAction
  }

  sendActions() {
    return this._sendActions
  }

  sendActionForKey(configKey) {
    return _.findWhere(this._sendActions, {configKey});
  }

  availableSendActionsForDraft(draft) {
    return this._sendActions.filter((sendAction) => sendAction.isAvailableForDraft({draft}))
  }

  orderedSendActionsForDraft(draft) {
    const configKeys = this._sendActions.map(({configKey} = {}) => configKey);

    let preferredKey = NylasEnv.config.get(ACTION_CONFIG_KEY);
    if (!preferredKey || !configKeys.includes(preferredKey)) {
      preferredKey = DefaultSendActionKey;
    }

    let preferred = _.findWhere(this._sendActions, {configKey: preferredKey});
    if (!preferred || !preferred.isAvailableForDraft({draft})) {
      preferred = DefaultSendAction
    }
    const rest = (
      _.without(this._sendActions, preferred)
      .filter((sendAction) => sendAction.isAvailableForDraft({draft}))
    )

    return {preferred, rest};
  }

  _onComposerExtensionsChanged = () => {
    this._sendActions = getSendActions()
    this.trigger()
  }
}

export default new SendActionsStore()
