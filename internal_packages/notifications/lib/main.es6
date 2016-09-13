/* eslint no-unused-vars:0 */

import {ComponentRegistry, WorkspaceStore} from 'nylas-exports';
import ActivitySidebar from "./sidebar/activity-sidebar";
import NotificationStore from './notifications-store';
import ConnectionStatusHeader from './headers/connection-status-header';
import AccountErrorHeader from './headers/account-error-header';
import NotificationsHeader from "./headers/notifications-header";
import TrialRemainingHeader from "./headers/trial-remaining-header";

export function activate() {
  ComponentRegistry.register(ActivitySidebar, {location: WorkspaceStore.Location.RootSidebar});
  ComponentRegistry.register(NotificationsHeader, {location: WorkspaceStore.Sheet.Global.Header});
  ComponentRegistry.register(ConnectionStatusHeader, {location: WorkspaceStore.Sheet.Global.Header});
  ComponentRegistry.register(AccountErrorHeader, {location: WorkspaceStore.Sheet.Threads.Header});
  ComponentRegistry.register(TrialRemainingHeader, {location: WorkspaceStore.Sheet.Global.Header});
}

export function serialize() {}

export function deactivate() {
  ComponentRegistry.unregister(ActivitySidebar);
  ComponentRegistry.unregister(NotificationsHeader);
  ComponentRegistry.unregister(ConnectionStatusHeader);
  ComponentRegistry.unregister(AccountErrorHeader);
  ComponentRegistry.unregister(TrialRemainingHeader);
}
