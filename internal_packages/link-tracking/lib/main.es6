import {ComponentRegistry, ExtensionRegistry, Actions} from 'nylas-exports';
import LinkTrackingButton from './link-tracking-button';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingMessageExtension from './link-tracking-message-extension';
import LinkTrackingAfterSend from './link-tracking-after-send';


export function activate() {
  ComponentRegistry.register(LinkTrackingButton, {role: 'Composer:ActionButton'});
  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.register(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(LinkTrackingAfterSend.afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButton);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.unregister(LinkTrackingMessageExtension);
  this._unlistenSendDraftSuccess()
}
