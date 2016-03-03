/** @babel */
import {ComponentRegistry} from 'nylas-exports';
import {ToolbarSnooze, BulkThreadSnooze} from './snooze-toolbar-components';
import SnoozeQuickActionButton from './snooze-quick-action-button'
import SnoozeMailLabel from './snooze-mail-label'
import SnoozeStore from './snooze-store'


export function activate() {
  this.snoozeStore = new SnoozeStore()

  this.snoozeStore.activate()
  ComponentRegistry.register(ToolbarSnooze, {role: 'message:Toolbar'});
  ComponentRegistry.register(SnoozeQuickActionButton, {role: 'ThreadListQuickAction'});
  ComponentRegistry.register(BulkThreadSnooze, {role: 'thread:BulkAction'});
  ComponentRegistry.register(SnoozeMailLabel, {role: 'Thread:MailLabel'});
}

export function deactivate() {
  ComponentRegistry.unregister(ToolbarSnooze);
  ComponentRegistry.unregister(SnoozeQuickActionButton);
  ComponentRegistry.unregister(BulkThreadSnooze);
  ComponentRegistry.unregister(SnoozeMailLabel);
  this.snoozeStore.deactivate()
}

export function serialize() {

}
