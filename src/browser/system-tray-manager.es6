import {Tray, Menu, nativeImage} from 'electron';


function _getMenuTemplate(platform, application) {
  const template = [
    {
      label: 'New Message',
      click: () => application.emit('application:new-message'),
    },
    {
      label: 'Preferences',
      click: () => application.emit('application:open-preferences'),
    },
    {
      type: 'separator',
    },
    {
      label: 'Quit Nylas Mail',
      click: () => application.emit('application:quit'),
    },
  ];

  if (platform !== 'win32') {
    template.unshift({
      label: 'Open Inbox',
      click: () => application.emit('application:show-main-window'),
    });
  }

  return template;
}

function _getTooltip(unreadString) {
  return unreadString ? `${unreadString} unread messages` : '';
}

function _getIcon(iconPath, isTemplateImg) {
  if (!iconPath) {
    return nativeImage.createEmpty();
  }
  const icon = nativeImage.createFromPath(iconPath)
  if (isTemplateImg) {
    icon.setTemplateImage(true);
  }
  return icon;
}


class SystemTrayManager {

  constructor(platform, application) {
    this._platform = platform;
    this._application = application;
    this._iconPath = null;
    this._unreadString = null;
    this._tray = null;
    this.initTray();

    this._application.config.onDidChange('core.workspace.systemTray', ({newValue}) => {
      if (newValue === false) {
        this.destroyTray();
      } else {
        this.initTray();
      }
    });
  }

  initTray() {
    const enabled = (this._application.config.get('core.workspace.systemTray') !== false);
    const created = (this._tray !== null);

    if (enabled && !created) {
      this._tray = new Tray(_getIcon(this._iconPath));
      this._tray.setToolTip(_getTooltip(this._unreadString));
      this._tray.addListener('click', this._onClick);
      this._tray.setContextMenu(Menu.buildFromTemplate(_getMenuTemplate(this._platform, this._application)));
    }
  }

  _onClick = () => {
    if (this._platform !== 'darwin') {
      this._application.emit('application:show-main-window');
    }
  };

  updateTraySettings(iconPath, unreadString, isTemplateImg) {
    if ((this._iconPath === iconPath) && (this._unreadString === unreadString)) return;

    this._iconPath = iconPath;
    this._unreadString = unreadString;

    if (this._tray) {
      const icon = _getIcon(this._iconPath, isTemplateImg);
      const tooltip = _getTooltip(unreadString);
      this._tray.setImage(icon);
      this._tray.setToolTip(tooltip);
    }
  }

  destroyTray() {
    if (this._tray) {
      this._tray.removeListener('click', this._onClick);
      this._tray.destroy();
      this._tray = null;
    }
  }
}

export default SystemTrayManager;
