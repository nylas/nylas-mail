import {
  Actions,
  ComponentRegistry,
  ExtensionRegistry,
  RegisterDraftForPluginTask,
} from 'nylas-exports';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingMessageStatus from './open-tracking-message-status';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';
import {PLUGIN_ID, PLUGIN_URL} from './open-tracking-constants'

export function activate() {
  ComponentRegistry.register(OpenTrackingButton,
    {role: 'Composer:ActionButton'});

  ComponentRegistry.register(OpenTrackingIcon,
    {role: 'ThreadListIcon'});

  ComponentRegistry.register(OpenTrackingMessageStatus,
    {role: 'MessageHeaderStatus'});

  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);

  const errorMessage = `There was a problem saving your read receipt \
settings. You will not get a read receipt for this message.`

  this._usub = Actions.sendDraftSuccess.listen(({message, draftClientId}) => {
    if (!NylasEnv.isMainWindow()) return;
    if (message.metadataForPluginId(PLUGIN_ID)) {
      const task = new RegisterDraftForPluginTask({
        errorMessage,
        draftClientId,
        messageId: message.id,
        pluginServerUrl: `${PLUGIN_URL}/plugins/register-message`,
      });
      Actions.queueTask(task);
    }
  })
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButton);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ComponentRegistry.unregister(OpenTrackingMessageStatus);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
  this._usub()
}
