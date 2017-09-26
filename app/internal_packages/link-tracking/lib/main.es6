import { ComponentRegistry, ExtensionRegistry } from 'mailspring-exports';
import { HasTutorialTip } from 'mailspring-component-kit';

import LinkTrackingButton from './link-tracking-button';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingMessageExtension from './link-tracking-message-extension';

const LinkTrackingButtonWithTutorialTip = HasTutorialTip(LinkTrackingButton, {
  title: 'Track links in this email',
  instructions:
    'When link tracking is turned on, Mailspring will notify you when recipients click links in this email.',
});

export function activate() {
  ComponentRegistry.register(LinkTrackingButtonWithTutorialTip, {
    role: 'Composer:ActionButton',
  });

  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);

  ExtensionRegistry.MessageView.register(LinkTrackingMessageExtension);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButtonWithTutorialTip);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.unregister(LinkTrackingMessageExtension);
}
