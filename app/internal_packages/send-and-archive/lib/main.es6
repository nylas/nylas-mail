import { ExtensionRegistry } from 'mailspring-exports';
import * as SendAndArchiveExtension from './send-and-archive-extension';

export function activate() {
  ExtensionRegistry.Composer.register(SendAndArchiveExtension);
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SendAndArchiveExtension);
}
