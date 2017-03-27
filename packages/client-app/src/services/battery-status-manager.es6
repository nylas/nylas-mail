import moment from 'moment-timezone'
import Actions from '../flux/actions'

class BatteryStatusManager {
  constructor() {
    this._callbacks = [];
    this._battery = null;
    this._lastChangeTime = Date.now();
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
    const changeTime = Date.now();
    Actions.recordUserEvent("Battery State Changed", {
      oldState: this.isBatteryCharging() ? 'battery' : 'ac',
      oldStateDuration: Math.min(changeTime - this._lastChangeTime, moment.duration(12, 'hours').asMilliseconds()),
    });
    this._lastChangeTime = changeTime;
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
