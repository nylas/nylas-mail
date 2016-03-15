/** @babel */
import {ExtensionRegistry} from 'nylas-exports';
import EmojiComposerExtension from './emoji-composer-extension';

export function activate() {
  ExtensionRegistry.Composer.register(EmojiComposerExtension);
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(EmojiComposerExtension);
}
