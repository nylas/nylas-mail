import {ComponentRegistry} from 'nylas-exports';
import ThreadSharingButton from "./thread-sharing-button";
import ExternalThreads from "./external-threads"

export function activate() {
  ComponentRegistry.register(ThreadSharingButton, {
    role: 'ThreadActionsToolbarButton',
  });
  ExternalThreads.activate();
}

export function deactivate() {
  ComponentRegistry.unregister(ThreadSharingButton);
  ExternalThreads.deactivate();
}
