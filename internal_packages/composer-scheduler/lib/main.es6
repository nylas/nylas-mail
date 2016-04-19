import ProposedTimeEvent from './calendar/proposed-time-event'
import ProposedTimePicker from './calendar/proposed-time-picker'
import NewEventCardContainer from './composer/new-event-card-container'
import SchedulerComposerButton from './composer/scheduler-composer-button';
import ProposedTimeCalendarStore from './proposed-time-calendar-store'
import SchedulerComposerExtension from './composer/scheduler-composer-extension';

import {
  WorkspaceStore,
  ComponentRegistry,
  ExtensionRegistry,
} from 'nylas-exports'

export function activate() {
  if (NylasEnv.getWindowType() === 'calendar') {
    ProposedTimeCalendarStore.activate()

    NylasEnv.getCurrentWindow().setMinimumSize(480, 250)
    WorkspaceStore.defineSheet('Main', {root: true},
      {popout: ['Center']})

    ComponentRegistry.register(ProposedTimeEvent,
      {role: 'Calendar:Event'});

    ComponentRegistry.register(ProposedTimePicker,
      {location: WorkspaceStore.Location.Center})
  } else {
    ComponentRegistry.register(NewEventCardContainer,
      {role: 'Composer:Footer'});

    ComponentRegistry.register(SchedulerComposerButton,
      {role: 'Composer:ActionButton'});

    ExtensionRegistry.Composer.register(SchedulerComposerExtension)
  }
}

export function serialize() {
}

export function deactivate() {
  if (NylasEnv.getWindowType() === 'calendar') {
    ProposedTimeCalendarStore.deactivate()
    ComponentRegistry.unregister(ProposedTimeEvent);
    ComponentRegistry.unregister(ProposedTimePicker);
  } else {
    ComponentRegistry.unregister(NewEventCardContainer);
    ComponentRegistry.unregister(SchedulerComposerButton);
    ExtensionRegistry.Composer.unregister(SchedulerComposerExtension);
  }
}
