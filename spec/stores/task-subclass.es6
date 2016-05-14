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
  performRemote() { return Promise.resolve(Task.Status.Success) }
}

export class KillsTaskA extends Task {
  shouldDequeueOtherTask(other) { return other instanceof TaskSubclassA }
  performRemote() { return new Promise(() => {}) }
}

export class BlockedByTaskA extends Task {
  isDependentOnTask(other) { return other instanceof TaskSubclassA }
}

export class BlockingTask extends Task {
  isDependentOnTask(other) { return other instanceof BlockingTask }
}

export class TaskAA extends Task {
  performRemote() {
    const testError = new Error("Test Error")
    // We reject instead of `throw` because jasmine thinks this
    // `throw` is in the context of the test instead of the context
    // of the calling promise in task-queue.coffee
    return Promise.reject(testError)
  }
}

export class TaskBB extends Task {
  isDependentOnTask(other) { return other instanceof TaskAA }
  performRemote = jasmine.createSpy("performRemote")
}

export class OKTask extends Task {
  performRemote() { return Promise.resolve(Task.Status.Retry) }
}

export class BadTask extends Task {
  performRemote() { return Promise.resolve('lalal') }
}
