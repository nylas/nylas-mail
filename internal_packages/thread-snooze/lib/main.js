/** @babel */
import {ComponentRegistry} from 'nylas-exports';
import {ToolbarSnooze, QuickActionSnooze, BulkThreadSnooze} from './components';
import SnoozeStore from './snooze-store'


export function activate() {
  this.snoozeStore = new SnoozeStore()
  ComponentRegistry.register(ToolbarSnooze, {role: 'message:Toolbar'});
  ComponentRegistry.register(QuickActionSnooze, {role: 'ThreadListQuickAction'});
  ComponentRegistry.register(BulkThreadSnooze, {role: 'thread:BulkAction'});
}

export function deactivate() {
  ComponentRegistry.unregister(ToolbarSnooze);
  ComponentRegistry.unregister(QuickActionSnooze);
  ComponentRegistry.unregister(BulkThreadSnooze);
  this.snoozeStore.deactivate()
}

export function serialize() {

}
