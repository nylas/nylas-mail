import {ExtensionRegistry, ComponentRegistry} from 'nylas-exports';
import EmojiStore from './emoji-store';
import EmojiComposerExtension from './emoji-composer-extension';
import EmojiMessageExtension from './emoji-message-extension';
import EmojiButton from './emoji-button';

export function activate() {
  ExtensionRegistry.Composer.register(EmojiComposerExtension);
  ExtensionRegistry.MessageView.register(EmojiMessageExtension);
  ComponentRegistry.register(EmojiButton, {role: 'Composer:ActionButton'});
  EmojiStore.activate();
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(EmojiComposerExtension);
  ExtensionRegistry.MessageView.unregister(EmojiMessageExtension);
  ComponentRegistry.unregister(EmojiButton);
}
