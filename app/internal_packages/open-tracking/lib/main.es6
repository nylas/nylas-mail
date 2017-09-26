import { ComponentRegistry, ExtensionRegistry } from 'mailspring-exports';
import { HasTutorialTip } from 'mailspring-component-kit';
import OpenTrackingButton from './open-tracking-button';
import OpenTrackingIcon from './open-tracking-icon';
import OpenTrackingMessageStatus from './open-tracking-message-status';
import OpenTrackingComposerExtension from './open-tracking-composer-extension';

const OpenTrackingButtonWithTutorialTip = HasTutorialTip(OpenTrackingButton, {
  title: 'See when recipients open this email',
  instructions:
    'When enabled, Mailspring will notify you as soon as someone reads this message. Sending to a group? Mailspring shows you which recipients opened your email so you can follow up with precision.',
});

export function activate() {
  ComponentRegistry.register(OpenTrackingButtonWithTutorialTip, { role: 'Composer:ActionButton' });

  ComponentRegistry.register(OpenTrackingIcon, { role: 'ThreadListIcon' });

  ComponentRegistry.register(OpenTrackingMessageStatus, { role: 'MessageHeaderStatus' });

  ExtensionRegistry.Composer.register(OpenTrackingComposerExtension);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(OpenTrackingButtonWithTutorialTip);
  ComponentRegistry.unregister(OpenTrackingIcon);
  ComponentRegistry.unregister(OpenTrackingMessageStatus);
  ExtensionRegistry.Composer.unregister(OpenTrackingComposerExtension);
}
