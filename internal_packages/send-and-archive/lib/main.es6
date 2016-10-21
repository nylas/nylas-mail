import {ExtensionRegistry} from 'nylas-exports'
import * as SendAndArchiveExtension from './send-and-archive-extension'


export function activate() {
  ExtensionRegistry.Composer.register(SendAndArchiveExtension)
}

export function deactivate() {
  ExtensionRegistry.Composer.unregister(SendAndArchiveExtension)
}
