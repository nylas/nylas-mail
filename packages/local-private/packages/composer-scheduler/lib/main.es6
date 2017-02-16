import {
  WorkspaceStore,
  ComponentRegistry,
  ExtensionRegistry,
  CustomContenteditableComponents,
} from 'nylas-exports'

import {HasTutorialTip} from 'nylas-component-kit';

import ProposedTimeEvent from './calendar/proposed-time-event'
import ProposedTimePicker from './calendar/proposed-time-picker'
import NewEventCardContainer from './composer/new-event-card-container'
import SchedulerComposerButton from './composer/scheduler-composer-button';
import ProposedTimeCalendarStore from './proposed-time-calendar-store'
import SchedulerComposerExtension from './composer/scheduler-composer-extension';

const SchedulerComposerButtonWithTip = HasTutorialTip(SchedulerComposerButton, {
  title: "Create a new meeting request",
  instructions: "Click the <b>calendar icon</b> to send calendar invites or propose times to meet&mdash;all without leaving the inbox!",
});

export function activate() {
  if (NylasEnv.getWindowType() === 'scheduler-calendar') {
    ProposedTimeCalendarStore.activate()

    NylasEnv.getCurrentWindow().setMinimumSize(480, 250)

    ComponentRegistry.register(ProposedTimeEvent, {
      role: 'Calendar:Event',
    });

    ComponentRegistry.register(ProposedTimePicker, {
      location: WorkspaceStore.Location.Center,
    });
  } else {
    ComponentRegistry.register(SchedulerComposerButtonWithTip, {
      role: 'Composer:ActionButton',
    });

    ExtensionRegistry.Composer.register(SchedulerComposerExtension);

    CustomContenteditableComponents.register("NewEventCardContainer", NewEventCardContainer);
  }
}

export function serialize() {
}

export function deactivate() {
  if (NylasEnv.getWindowType() === 'scheduler-calendar') {
    ProposedTimeCalendarStore.deactivate()
    ComponentRegistry.unregister(ProposedTimeEvent);
    ComponentRegistry.unregister(ProposedTimePicker);
  } else {
    ComponentRegistry.unregister(SchedulerComposerButtonWithTip);
    ExtensionRegistry.Composer.unregister(SchedulerComposerExtension);
    CustomContenteditableComponents.unregister("NewEventCardContainer");
  }
}
