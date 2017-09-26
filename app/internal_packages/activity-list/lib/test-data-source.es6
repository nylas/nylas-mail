export default class TestDataSource {
  buildObservable() {
    return this;
  }

  manuallyTrigger = (messages = []) => {
    this.onNext(messages);
  };

  subscribe(onNext) {
    this.onNext = onNext;
    this.manuallyTrigger();
    const dispose = () => {
      this._unsub();
    };
    return { dispose };
  }
}
