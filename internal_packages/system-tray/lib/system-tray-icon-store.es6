import fs from 'fs';
import path from 'path';
import mkdirp from 'mkdirp';
import {remote, ipcRenderer} from 'electron';
import {UnreadBadgeStore, CanvasUtils} from 'nylas-exports';
const {canvasWithSystemTrayIconAndText} = CanvasUtils;
const {nativeImage} = remote
const mkdirpAsync = Promise.promisify(mkdirp)
const writeFile = Promise.promisify(fs.writeFile)

// Must be absolute real system path
// https://github.com/atom/electron/issues/1299
const BASE_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas.png');
const UNREAD_ICON_PATH = path.join(__dirname, '..', 'assets', process.platform, 'ic-systemtray-nylas-unread.png');
const TRAY_ICON_PATH = path.join(
  NylasEnv.getConfigDirPath(),
  'tray',
  'tray-icon.png'
);


class SystemTrayIconStore {

  constructor(platform) {
    this._platform = platform;

    this._unreadString = (+UnreadBadgeStore.count()).toLocaleString();
    this._unreadIcon = nativeImage.createFromPath(UNREAD_ICON_PATH);
    this._baseIcon = nativeImage.createFromPath(BASE_ICON_PATH);
    this._icon = this._getIconImg();
  }

  activate() {
    const iconDir = path.dirname(TRAY_ICON_PATH);
    mkdirpAsync(iconDir).then(()=> {
      writeFile(TRAY_ICON_PATH, this._icon.toPng())
      .then(()=> {
        ipcRenderer.send('update-system-tray', TRAY_ICON_PATH, this._unreadString);
        this._unsubscribe = UnreadBadgeStore.listen(this._onUnreadCountChanged);
      })
    });
  }

  _getIconImg(unreadString = this._unreadString) {
    const imgHandlers = {
      'darwin': () => {
        const img = new Image();
        let canvas = null;

        // toDataUrl always returns the @1x image data, so the assets/darwin/
        // contains an "@2x" image /without/ the @2x extension
        img.src = this._baseIcon.toDataURL();

        if (unreadString === '0') {
          canvas = canvasWithSystemTrayIconAndText(img, '');
        } else {
          canvas = canvasWithSystemTrayIconAndText(img, unreadString);
        }
        const pngData = nativeImage.createFromDataURL(canvas.toDataURL()).toPng();

        // creating from a buffer allows us to specify that the image is @2x
        const outputImg = nativeImage.createFromBuffer(pngData);
        return outputImg;
      },
      'default': () => {
        return unreadString !== '0' ? this._unreadIcon : this._baseIcon;
      },
    };

    return imgHandlers[this._platform in imgHandlers ? this._platform : 'default']();
  }

  _onUnreadCountChanged = () => {
    this._unreadString = (+UnreadBadgeStore.count()).toLocaleString();
    this._icon = this._getIconImg();
    writeFile(TRAY_ICON_PATH, this._icon.toPng())
    .then(() => {
      ipcRenderer.send('update-system-tray', TRAY_ICON_PATH, this._unreadString);
    });
  };

  deactivate() {
    if (this._unsubscribe) this._unsubscribe();
  }
}

export default SystemTrayIconStore;
