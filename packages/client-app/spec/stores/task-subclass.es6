import Task from '../../src/flux/tasks/task'

// We need to subclass in ES6 since coffeescript can't subclass an ES6
// object.
export class TaskSubclassA extends Task {
  constructor(val) {
    super(val);
    this.aProp = val
  }
}

export class TaskSubclassB extends Task {
  constructor(val) {
    super(val);
    this.bProp = val
  }
}

export class APITestTask extends Task {
  performLocal() { return Promise.resolve() }
}

export class KillsTaskA extends Task {
  shouldDequeueOtherTask(other) { return other instanceof TaskSubclassA }
}

export class BlockedByTaskA extends Task {
  isDependentOnTask(other) { return other instanceof TaskSubclassA }
}

export class BlockingTask extends Task {
  isDependentOnTask(other) { return other instanceof BlockingTask }
}

export class TaskAA extends Task {
}

export class TaskBB extends Task {
  isDependentOnTask(other) { return other instanceof TaskAA }
}

export class OKTask extends Task {
}

export class BadTask extends Task {
}
