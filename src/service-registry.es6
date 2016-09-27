class ServiceRegistry {
  constructor() {
    this._waitingForServices = {};
    this._services = {};
  }

  withService(name, callback) {
    if (this._services[name]) {
      process.nextTick(() => callback(this._services[name]));
    } else {
      this._waitingForServices[name] = this._waitingForServices[name] || [];
      this._waitingForServices[name].push(callback);
    }
  }

  registerService(name, obj) {
    this._services[name] = obj;
    if (this._waitingForServices[name]) {
      for (const callback of this._waitingForServices[name]) {
        callback(obj);
      }
      delete this._waitingForServices[name];
    }
  }

  unregisterService(name) {
    delete this._services[name];
  }
}

export default new ServiceRegistry()
