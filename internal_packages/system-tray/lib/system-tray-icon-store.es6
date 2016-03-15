import path from 'path';
import {ipcRenderer} from 'electron';
import {UnreadBadgeStore} from 'nylas-exports';

// Must be absolute real system path
// https://github.com/atom/electron/issues/1299
const INBOX_ZERO_ICON = path.join(__dirname, '..', 'assets', 'MenuItem-Inbox-Zero.png');
const INBOX_UNREAD_ICON = path.join(__dirname, '..', 'assets', 'MenuItem-Inbox-Full.png');
const INBOX_UNREAD_ALT_ICON = path.join(__dirname, '..', 'assets', 'MenuItem-Inbox-Full-NewItems.png');


class SystemTrayIconStore {

  static INBOX_ZERO_ICON = INBOX_ZERO_ICON;

  static INBOX_UNREAD_ICON = INBOX_UNREAD_ICON;

  static INBOX_UNREAD_ALT_ICON = INBOX_UNREAD_ALT_ICON;

  constructor() {
    this._windowBlurred = false;
    this._unsubscribers = [];
  }

  activate() {
    this._updateIcon()
    this._unsubscribers.push(UnreadBadgeStore.listen(this._updateIcon));

    ipcRenderer.on('browser-window-blur', this._onWindowBlur)
    ipcRenderer.on('browser-window-focus', this._onWindowFocus)
    this._unsubscribers.push(() => ipcRenderer.removeListener('browser-window-blur', this._onWindowBlur))
    this._unsubscribers.push(() => ipcRenderer.removeListener('browser-window-focus', this._onWindowFocus))
  }

  _getIconImageData(unreadCount, isWindowBlurred) {
    if (unreadCount === 0) {
      return {iconPath: INBOX_ZERO_ICON, isTemplateImg: true};
    }
    return isWindowBlurred ?
      {iconPath: INBOX_UNREAD_ALT_ICON, isTemplateImg: false} :
      {iconPath: INBOX_UNREAD_ICON, isTemplateImg: true};
  }

  _onWindowBlur = ()=> {
    // Set state to blurred, but don't trigger a change. The icon should only be
    // updated when the count changes
    this._windowBlurred = true;
  };

  _onWindowFocus = ()=> {
    // Make sure that as long as the window is focused we never use the alt icon
    this._windowBlurred = false;
    this._updateIcon();
  };

  _updateIcon = () => {
    const count = UnreadBadgeStore.count()
    const unreadString = (+count).toLocaleString();
    const {iconPath, isTemplateImg} = this._getIconImageData(count, this._windowBlurred);
    ipcRenderer.send('update-system-tray', iconPath, unreadString, isTemplateImg);
  };

  deactivate() {
    this._unsubscribers.forEach(unsub => unsub())
  }
}

export default SystemTrayIconStore;
