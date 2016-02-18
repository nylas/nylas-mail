/** @babel */
import Reflux from 'reflux';

const SnoozeActions = Reflux.createActions([
  'snoozeThreads',
])

for (const key in SnoozeActions) {
  SnoozeActions[key].sync = true
}

export default SnoozeActions
