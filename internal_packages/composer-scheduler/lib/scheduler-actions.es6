import {Reflux} from 'nylas-exports'

const SchedulerActions = Reflux.createActions([
  'confirmChoices',
  'changeDuration',
  'clearProposals',
  'removeProposedTime',
  'addToProposedTimeBlock',
  'startProposedTimeBlock',
  'endProposedTimeBlock',
])

for (const key in SchedulerActions) {
  if ({}.hasOwnProperty.call(SchedulerActions, key)) {
    SchedulerActions[key].sync = true
  }
}

if (!NylasEnv.inSpecMode()) {
  NylasEnv.actionBridge.registerGlobalAction({
    scope: "SchedulerActions",
    name: "confirmChoices",
    actionFn: SchedulerActions.confirmChoices,
  });
}

export default SchedulerActions
