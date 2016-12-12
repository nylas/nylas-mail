import _ from 'underscore'
import {Reflux} from 'nylas-exports'

const globalSchedulerActions = Reflux.createActions([
  'confirmChoices',
])

const localSchedulerActions = Reflux.createActions([
  'changeDuration',
  'clearProposals',
  'removeEventCard',
  'insertNewEventCard',
  'removeProposedTime',
  'addToProposedTimeBlock',
  'startProposedTimeBlock',
  'endProposedTimeBlock',
])

const SchedulerActions = _.extend(localSchedulerActions, globalSchedulerActions)

for (const key of Object.keys(SchedulerActions)) {
  SchedulerActions[key].sync = true
}

NylasEnv.registerGlobalActions({
  pluginName: "SchedulerActions",
  actions: globalSchedulerActions,
});

export default SchedulerActions
