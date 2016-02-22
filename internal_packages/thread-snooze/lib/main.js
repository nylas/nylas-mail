/** @babel */
import {ComponentRegistry} from 'nylas-exports';
import {ToolbarSnooze, BulkThreadSnooze} from './toolbar-components';
import QuickActionSnoozeButton from './quick-action-snooze-button'
import SnoozeStore from './snooze-store'


export function activate() {
  this.snoozeStore = new SnoozeStore()
  ComponentRegistry.register(ToolbarSnooze, {role: 'message:Toolbar'});
  ComponentRegistry.register(QuickActionSnoozeButton, {role: 'ThreadListQuickAction'});
  ComponentRegistry.register(BulkThreadSnooze, {role: 'thread:BulkAction'});
}

export function deactivate() {
  ComponentRegistry.unregister(ToolbarSnooze);
  ComponentRegistry.unregister(QuickActionSnoozeButton);
  ComponentRegistry.unregister(BulkThreadSnooze);
  this.snoozeStore.deactivate()
}

export function serialize() {

}
