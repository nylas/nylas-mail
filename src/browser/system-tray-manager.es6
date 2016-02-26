import fs from 'fs';
import {Tray, Menu, nativeImage} from 'electron';


function _getMenuTemplate(platform, application) {
  const template = [
    {
      label: 'New Message',
      click: ()=> application.emit('application:new-message'),
    },
    {
      label: 'Preferences',
      click: ()=> application.emit('application:open-preferences'),
    },
    {
      type: 'separator',
    },
    {
      label: 'Quit N1',
      click: ()=> application.emit('application:quit'),
    },
  ];

  if (platform !== 'win32') {
    template.unshift({
      label: 'Open Inbox',
      click: ()=> application.emit('application:show-main-window'),
    });
  }

  return template;
}

function _getTooltip(unreadString) {
  return unreadString ? '' : `${unreadString} unread messages`;
}

function _getIcon(iconPath) {
  if (!iconPath) return nativeImage.createEmpty()
  try {
    fs.accessSync(iconPath, fs.F_OK | fs.R_OK)
    const buffer = fs.readFileSync(iconPath);
    if (buffer.length > 0) {
      const out2x = nativeImage.createFromBuffer(buffer, 2);
      out2x.setTemplateImage(true);
      return out2x;
    }
    return nativeImage.createEmpty();
  } catch (e) {
    return nativeImage.createEmpty();
  }
}


class SystemTrayManager {

  constructor(platform, application) {
    this._platform = platform;
    this._application = application;
    this._iconPath = null;
    this._tray = null;
    this._initTray();

    this._application.config.onDidChange('core.workspace.systemTray', () => {
      this.destroy()
      this._initTray()
    })
  }

  _initTray() {
    if (this._application.config.get('core.workspace.systemTray') !== false) {
      this._tray = new Tray(_getIcon(this._iconPath));
      this._tray.setToolTip(_getTooltip());
      this._tray.addListener('click', this._onClick);
      this._tray.setContextMenu(Menu.buildFromTemplate(_getMenuTemplate(this._platform, this._application)));
      this._unsubscribe = ()=> this._tray.removeListener('click', this._onClick);
    }
  }

  _onClick = () => {
    if (this._platform !== 'darwin') {
      this._application.emit('application:show-main-window');
    }
  }

  setTrayCount(iconPath, unreadString) {
    if (!this._tray) return;
    this._iconPath = iconPath;

    const icon = _getIcon(this._iconPath);
    const tooltip = _getTooltip(unreadString);
    this._tray.setImage(icon);
    this._tray.setToolTip(tooltip);
  }

  destroy() {
    if (!this._tray) return;
    this._unsubscribe();
    this._tray.destroy();
  }
}

export default SystemTrayManager;
