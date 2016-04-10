import {Reflux} from 'nylas-exports'

const SchedulerActions = Reflux.createActions([
  'confirmChoices',
  'changeDuration',
  'removeProposedTime',
  'addProposedTime',
])

for (const key in SchedulerActions) {
  if ({}.hasOwnProperty.call(SchedulerActions, key)) {
    SchedulerActions[key].sync = true
  }
}

NylasEnv.actionBridge.registerGlobalAction({
  scope: "SchedulerActions",
  name: "confirmChoices",
  actionFn: SchedulerActions.confirmChoices,
});

export default SchedulerActions
