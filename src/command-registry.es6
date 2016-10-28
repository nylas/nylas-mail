import { Emitter, Disposable, CompositeDisposable } from 'event-kit';

export default class CommandRegistry {
  constructor() {
    this.emitter = new Emitter();
    this.listenerCounts = {};
    this.listenerCountChanges = {};
  }

  add(target, commandName, callback) {
    if (typeof commandName === 'object') {
      const commands = commandName;
      const disposable = new CompositeDisposable();
      for (const subcommandName of Object.keys(commands)) {
        const subCallback = commands[subcommandName];
        disposable.add(this.add(target, subcommandName, subCallback));
      }
      return disposable;
    }

    if (typeof callback !== 'function') {
      throw new Error("Can't register a command with non-function callback.");
    }

    if (typeof target === 'string') {
      throw new Error("Commands can no longer be registered to CSS selectors. Consider using KeyCommandRegion instead.");
    }

    target.addEventListener(commandName, callback);
    this.listenerCountChanges[commandName] = (this.listenerCountChanges[commandName] || 0) + 1;
    this.flushChangesSoon();

    return new Disposable(() => {
      target.removeEventListener(commandName, callback);
      this.listenerCountChanges[commandName] = (this.listenerCountChanges[commandName] || 0) - 1;
      this.flushChangesSoon();
    });
  }

  listenerCountForCommand(commandName) {
    return (this.listenerCounts[commandName] || 0) + (this.listenerCountChanges[commandName] || 0);
  }

  // Public: Simulate the dispatch of a command on a DOM node.
  //
  // This can be useful for testing when you want to simulate the invocation of a
  // command on a detached DOM node. Otherwise, the DOM node in question needs to
  // be attached to the document so the event bubbles up to the root node to be
  // processed.
  //
  // * `target` The DOM node at which to start bubbling the command event.
  // * `commandName` {String} indicating the name of the command to dispatch.
  dispatch(commandName, detail) {
    const event = new CustomEvent(commandName, {bubbles: true, detail});
    return document.activeElement.dispatchEvent(event);
  }

  flushChangesSoon = () => {
    if (this.pendingEmit) { return; }
    this.pendingEmit = true;

    setTimeout(() => {
      this.pendingEmit = false;

      let changed = false;
      for (const commandName of Object.keys(this.listenerCountChanges)) {
        const val = this.listenerCountChanges[commandName];
        this.listenerCounts[commandName] = (this.listenerCounts[commandName] || 0) + val;
        if (val !== 0) { changed = true; }
      }
      this.listenerCountChanges = {};
      if (changed) {
        this.emitter.emit('commands-changed');
      }
    }, 100);
  }

  onRegistedCommandsChanged(callback) {
    return this.emitter.on('commands-changed', callback);
  }
}
