import {ComponentRegistry} from 'nylas-exports';
import MessageAttachments from './message-attachments'

export function activate() {
  ComponentRegistry.register(MessageAttachments, {role: 'MessageAttachments'})
}

export function deactivate() {
  ComponentRegistry.unregister(MessageAttachments);
}
