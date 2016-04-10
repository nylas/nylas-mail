import {
  ComponentRegistry,
  ExtensionRegistry,
} from 'nylas-exports';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingMessageStatus from './open-tracking-message-status';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';

export function activate() {
  ComponentRegistry.register(OpenTrackingButton,
    {role: 'Composer:ActionButton'});

  ComponentRegistry.register(OpenTrackingIcon,
    {role: 'ThreadListIcon'});

  ComponentRegistry.register(OpenTrackingMessageStatus,
    {role: 'MessageHeaderStatus'});

  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButton);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ComponentRegistry.unregister(OpenTrackingMessageStatus);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
}
