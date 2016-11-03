import { generateTempId } from './flux/models/utils';

// A small object that keeps track of the current animation state of the
// application. You can use it to defer work until animations have finished.
// Integrated with our fork of ReactCSSTransitionGroup
//
//  PriorityUICoordinator.settle.then ->
//   # Do something expensive
//
class PriorityUICoordinator {
  constructor() {
    this.tasks = {};
    this.settle = Promise.resolve();
    setInterval(() => this.detectOrphanedTasks(), 1000);
  }

  beginPriorityTask() {
    if (Object.keys(this.tasks).length === 0) {
      this.settle = new Promise((resolve) => {
        this.settlePromiseResolve = resolve;
      });
    }

    const id = generateTempId();
    this.tasks[id] = Date.now();
    return id;
  }

  endPriorityTask(id) {
    if (!id) {
      throw new Error("You must provide a task id to endPriorityTask");
    }
    delete this.tasks[id];
    if (Object.keys(this.tasks).length === 0) {
      if (this.settlePromiseResolve) {
        this.settlePromiseResolve();
      }
      this.settlePromiseResolve = null;
    }
  }

  detectOrphanedTasks() {
    const now = Date.now();
    const threshold = 15000; // milliseconds

    for (const id of Object.keys(this.tasks)) {
      const timestamp = this.tasks[id];
      if (now - timestamp > threshold) {
        console.log(`PriorityUICoordinator detected oprhaned priority task lasting ${threshold}ms. Ending.`);
        this.endPriorityTask(id);
      }
    }
  }

  busy() {
    return Object.keys(this.tasks).length > 0;
  }
}

export default new PriorityUICoordinator();
