import {
  ComponentRegistry,
  ExtensionRegistry,
} from 'nylas-exports';
import LinkTrackingButton from './link-tracking-button';
import LinkTrackingComposerExtension from './link-tracking-composer-extension';
import LinkTrackingMessageExtension from './link-tracking-message-extension';


export function activate() {
  ComponentRegistry.register(LinkTrackingButton,
    {role: 'Composer:ActionButton'});

  ExtensionRegistry.Composer.register(LinkTrackingComposerExtension);

  ExtensionRegistry.MessageView.register(LinkTrackingMessageExtension);
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(LinkTrackingButton);
  ExtensionRegistry.Composer.unregister(LinkTrackingComposerExtension);
  ExtensionRegistry.MessageView.unregister(LinkTrackingMessageExtension);
}
