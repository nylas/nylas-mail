import path from 'path';
import NylasStore from 'nylas-store';
import {remote, ipcRenderer} from 'electron';
import {UnreadBadgeStore, CanvasUtils} from 'nylas-exports';
const NativeImage = remote.require('native-image');
const Menu = remote.require('menu');
const {canvasWithSystemTrayIconAndText} = CanvasUtils;

// Must be absolute real system path
// https://github.com/atom/electron/issues/1299
const BASE_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas.png');
const UNREAD_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas-unread.png');

const _menuTemplate = [
  {
    label: 'New Message',
    click: ()=> ipcRenderer.send('command', 'application:new-message'),
  },
  {
    label: 'Preferences',
    click: ()=> ipcRenderer.send('command', 'application:open-preferences'),
  },
  {
    type: 'separator',
  },
  {
    label: 'Quit N1',
    click: ()=> ipcRenderer.send('command', 'application:quit'),
  },
];

if (process.platform !== 'win32') {
  _menuTemplate.unshift({
    label: 'Open Inbox',
    click: ()=> ipcRenderer.send('command', 'application:show-main-window'),
  });
}

const _buildMenu = ()=> {
  return Menu.buildFromTemplate(_menuTemplate);
};

class TrayStore extends NylasStore {

  constructor(platform) {
    super();
    this._platform = platform;

    this._unreadIcon = NativeImage.createFromPath(UNREAD_ICON_PATH);
    this._unreadString = (+UnreadBadgeStore.count()).toLocaleString();
    this._baseIcon = NativeImage.createFromPath(BASE_ICON_PATH);
    this._menu = _buildMenu();
    this._icon = this._getIconImg();

    this.listenTo(UnreadBadgeStore, this._onUnreadCountChanged);
  }

  icon() {
    return this._icon;
  }

  tooltip() {
    return `${this._unreadString} unread messages`;
  }

  menu() {
    return this._menu;
  }

  _getIconImg() {
    const imgHandlers = {
      'darwin': ()=> {
        const img = new Image();
        var canvas = null;

        // toDataUrl always returns the @1x image data, so the assets/darwin/
        // contains an "@2x" image /without/ the @2x extension
        img.src = this._baseIcon.toDataURL();

        if (this._unreadString === '0') {
          canvas = canvasWithSystemTrayIconAndText(img, '');
        } else {
          canvas = canvasWithSystemTrayIconAndText(img, this._unreadString);
        }
        const pngData = NativeImage.createFromDataURL(canvas.toDataURL()).toPng();

        // creating from a buffer allows us to specify that the image is @2x
        const out2x = NativeImage.createFromBuffer(pngData, 2);
        out2x.setTemplateImage(true);
        return out2x;
      },
      'default': ()=> {
        return this._unreadString !== '0' ? this._unreadIcon : this._baseIcon;
      },
    };

    return imgHandlers[this._platform in imgHandlers ? this._platform : 'default']();
  }

  _onUnreadCountChanged() {
    this._unreadString = (+UnreadBadgeStore.count()).toLocaleString();
    this._icon = this._getIconImg();
    this.trigger();
  }
}

export default TrayStore;
