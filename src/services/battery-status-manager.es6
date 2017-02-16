
class BatteryStatusManager {
  constructor() {
    this._callbacks = [];
    this._battery = null;
  }

  async activate() {
    if (this._battery) {
      return;
    }
    this._battery = await navigator.getBattery();
    this._battery.addEventListener('chargingchange', this._onChargingChange);
  }

  deactivate() {
    if (!this._battery) {
      return;
    }
    this._battery.removeEventListener('chargingchange', this._onChargingChange);
    this._battery = null;
  }

  _onChargingChange = () => {
    this._callbacks.forEach(cb => cb());
  }

  onChange(callback) {
    this._callbacks.push(callback);
  }

  isBatteryCharging() {
    if (!this._battery) {
      return false;
    }
    return this._battery.charging;
  }
}

const manager = new BatteryStatusManager();
manager.activate();
export default manager;
