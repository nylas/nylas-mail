
import {ComponentRegistry, ExtensionRegistry, Actions} from 'nylas-exports';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingMessageStatus from './open-tracking-message-status';
import OpenTrackingAfterSend from './open-tracking-after-send';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';

export function activate() {
  ComponentRegistry.register(OpenTrackingButton, {role: 'Composer:ActionButton'});
  ComponentRegistry.register(OpenTrackingIcon, {role: 'ThreadListIcon'});
  ComponentRegistry.register(OpenTrackingMessageStatus, {role: 'MessageHeaderStatus'});
  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess = Actions.sendDraftSuccess.listen(OpenTrackingAfterSend.afterDraftSend);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButton);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ComponentRegistry.unregister(OpenTrackingMessageStatus);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
  this._unlistenSendDraftSuccess()
}
