import SystemTray from './system-tray';
const platform = process.platform;

let systemTray;
let unsubConfig = ()=>{};
const onSystemTrayToggle = (showSystemTray)=> {
  if (showSystemTray.newValue) {
    systemTray = new SystemTray(platform);
  } else {
    systemTray.destroy();
    systemTray = null;
  }
};

export function deactivate() {
  if (systemTray) {
    systemTray.destroy();
    systemTray = null;
  }
  unsubConfig();
}

export function activate() {
  deactivate();
  unsubConfig = NylasEnv.config.onDidChange('core.showSystemTray', onSystemTrayToggle).dispose;
  if (NylasEnv.config.get('core.showSystemTray')) {
    systemTray = new SystemTray(platform);
  }
}

export function serialize() {

}
