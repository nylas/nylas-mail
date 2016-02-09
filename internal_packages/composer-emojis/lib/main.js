/** @babel */
import {ExtensionRegistry} from 'nylas-exports';
import EmojisComposerExtension from './emojis-composer-extension';

export function activate() {
  ExtensionRegistry.Composer.register(EmojisComposerExtension);
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(EmojisComposerExtension);
}
