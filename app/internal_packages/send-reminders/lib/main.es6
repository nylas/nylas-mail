import { ComponentRegistry, ExtensionRegistry } from 'mailspring-exports';
import { HasTutorialTip } from 'mailspring-component-kit';
import SendRemindersThreadTimestamp from './send-reminders-thread-timestamp';
import SendRemindersComposerButton from './send-reminders-composer-button';
import SendRemindersToolbarButton from './send-reminders-toolbar-button';
import {
  ScheduledReminderThreadHeader,
  NotificationExplanationMessageHeader,
} from './send-reminders-headers';
import SendRemindersStore from './send-reminders-store';
import * as ThreadListExtension from './send-reminders-thread-list-extension';
import * as AccountSidebarExtension from './send-reminders-account-sidebar-extension';

const ComposerButtonWithTip = HasTutorialTip(SendRemindersComposerButton, {
  title: 'Get reminded!',
  instructions:
    "Get reminded if you don't receive a reply for this message within a specified time.",
});

export function activate() {
  ComponentRegistry.register(ComposerButtonWithTip, { role: 'Composer:ActionButton' });
  ComponentRegistry.register(SendRemindersToolbarButton, { role: 'ThreadActionsToolbarButton' });
  ComponentRegistry.register(SendRemindersThreadTimestamp, { role: 'ThreadListTimestamp' });
  ComponentRegistry.register(NotificationExplanationMessageHeader, { role: 'MessageHeader' });
  ComponentRegistry.register(ScheduledReminderThreadHeader, { role: 'MessageListHeaders' });
  ExtensionRegistry.ThreadList.register(ThreadListExtension);
  ExtensionRegistry.AccountSidebar.register(AccountSidebarExtension);
  SendRemindersStore.activate();
}

export function deactivate() {
  ComponentRegistry.unregister(ComposerButtonWithTip);
  ComponentRegistry.unregister(SendRemindersToolbarButton);
  ComponentRegistry.unregister(SendRemindersThreadTimestamp);
  ComponentRegistry.unregister(NotificationExplanationMessageHeader);
  ComponentRegistry.unregister(ScheduledReminderThreadHeader);
  ExtensionRegistry.ThreadList.unregister(ThreadListExtension);
  ExtensionRegistry.AccountSidebar.unregister(AccountSidebarExtension);
  SendRemindersStore.deactivate();
}
