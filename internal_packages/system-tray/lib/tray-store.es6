import path from 'path';
import remote from 'remote';
import ipc from 'ipc';
import NylasStore from 'nylas-store';
import {UnreadCountStore, CanvasUtils} from 'nylas-exports';
const NativeImage = remote.require('native-image');
const Menu = remote.require('menu');
const {canvasWithSystemTrayIconAndText} = CanvasUtils;

// Must be absolute real system path
// https://github.com/atom/electron/issues/1299
const BASE_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas.png');
const UNREAD_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas-unread.png');

const menuTemplate = [
  {
    label: 'New Message',
    click: ()=> ipc.send('command', 'application:new-message'),
  },
  {
    label: 'Preferences',
    click: ()=> ipc.send('command', 'application:open-preferences'),
  },
  {
    type: 'separator',
  },
  {
    label: 'Quit N1',
    click: ()=> ipc.send('command', 'application:quit'),
  },
];

if (process.platform === 'darwin') {
  menuTemplate.unshift({
    label: 'Open Inbox',
    click: ()=> ipc.send('command', 'application:show-main-window'),
  });
}

const _buildMenu = ()=> {
  return Menu.buildFromTemplate(menuTemplate);
};

class TrayStore extends NylasStore {

  constructor(platform) {
    super();
    this._platform = platform;

    this._unreadIcon = NativeImage.createFromPath(UNREAD_ICON_PATH);
    this._baseIcon = NativeImage.createFromPath(BASE_ICON_PATH);
    this._unreadCount = UnreadCountStore.count() || 0;
    this._menu = _buildMenu(platform);
    this._icon = this._getIconImg();
    this.listenTo(UnreadCountStore, this._onUnreadCountChanged);
  }

  unreadCount() {
    return this._unreadCount;
  }

  icon() {
    return this._icon;
  }

  tooltip() {
    return `${this._unreadCount} unread messages`;
  }

  menu() {
    return this._menu;
  }

  _getIconImg(platform = this._platform, unreadCount = this._unreadCount) {
    const imgHandlers = {
      'darwin': ()=> {
        const img = new Image();
        // This is synchronous because it's a data url
        img.src = this._baseIcon.toDataUrl();
        const count = this._unreadCount || '';
        const canvas = canvasWithSystemTrayIconAndText(img, count.toString());
        return NativeImage.createFromDataUrl(canvas.toDataURL());
      },
      'default': ()=> {
        return unreadCount > 0 ? this._unreadIcon : this._baseIcon;
      },
    };

    return imgHandlers[platform in imgHandlers ? platform : 'default']();
  }

  _onUnreadCountChanged() {
    this._unreadCount = UnreadCountStore.count();
    this._icon = this._getIconImg();
    this.trigger();
  }
}

export default TrayStore;
