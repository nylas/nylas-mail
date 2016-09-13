import {ComponentRegistry} from 'nylas-exports';
import {HasTutorialTip} from 'nylas-component-kit';

import {ToolbarSnooze, QuickActionSnooze} from './snooze-buttons';
import SnoozeMailLabel from './snooze-mail-label'
import SnoozeStore from './snooze-store'


export function activate() {
  this.snoozeStore = new SnoozeStore()

  const ToolbarSnoozeWithTutorialTip = HasTutorialTip(ToolbarSnooze, {
    title: "Handle it later!",
    instructions: "Snooze this email and it'll return to your inbox later. Click here or swipe across the thread in your inbox to snooze.",
  });

  this.snoozeStore.activate()
  ComponentRegistry.register(ToolbarSnoozeWithTutorialTip, {role: 'ThreadActionsToolbarButton'});
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
