import SystemTrayIconStore from './system-tray-icon-store';
const platform = process.platform;

export function activate() {
  this.store = new SystemTrayIconStore(platform);
  this.store.activate();
}

export function deactivate() {
  this.store.deactivate();
}

export function serialize() {

}
