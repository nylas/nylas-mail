/** @babel */
import {ComponentRegistry} from 'nylas-exports';
import {ToolbarSnooze, QuickActionSnooze} from './snooze-buttons';
import SnoozeMailLabel from './snooze-mail-label'
import SnoozeStore from './snooze-store'


export function activate() {
  this.snoozeStore = new SnoozeStore()

  this.snoozeStore.activate()
  ComponentRegistry.register(ToolbarSnooze, {role: 'ThreadActionsToolbarButton'});
  ComponentRegistry.register(QuickActionSnooze, {role: 'ThreadListQuickAction'});
  ComponentRegistry.register(SnoozeMailLabel, {role: 'Thread:MailLabel'});
}

export function deactivate() {
  ComponentRegistry.unregister(ToolbarSnooze);
  ComponentRegistry.unregister(QuickActionSnooze);
  ComponentRegistry.unregister(SnoozeMailLabel);
  this.snoozeStore.deactivate()
}

export function serialize() {

}
