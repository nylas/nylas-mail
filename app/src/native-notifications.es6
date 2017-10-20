/* eslint global-require: 0 */
let MacNotifierNotification = null;
if (process.platform === 'darwin') {
  try {
    MacNotifierNotification = require('node-mac-notifier');
  } catch (err) {
    console.error(
      'node-mac-notifier (a platform-specific optionalDependency) was not installed correctly! Check the Travis build log for errors.'
    );
  }
}

class NativeNotifications {
  constructor() {
    if (MacNotifierNotification) {
      this._macNotificationsByTag = {};
      AppEnv.onBeforeUnload(() => {
        Object.keys(this._macNotificationsByTag).forEach(key => {
          this._macNotificationsByTag[key].close();
        });
        return true;
      });
    }
  }
  displayNotification({ title, subtitle, body, tag, canReply, onActivate = () => {} } = {}) {
    let notif = null;

    if (MacNotifierNotification) {
      if (tag && this._macNotificationsByTag[tag]) {
        this._macNotificationsByTag[tag].close();
      }
      notif = new MacNotifierNotification(title, {
        bundleId: 'com.mailspring.mailspring',
        canReply: canReply,
        subtitle: subtitle,
        body: body,
        id: tag,
      });
      notif.addEventListener('reply', ({ response }) => {
        onActivate({ response, activationType: 'replied' });
      });
      notif.addEventListener('click', () => {
        onActivate({ response: null, activationType: 'clicked' });
      });
      if (tag) {
        this._macNotificationsByTag[tag] = notif;
      }
    } else {
      notif = new Notification(title, {
        silent: true,
        body: subtitle,
        tag: tag,
      });
      notif.onclick = onActivate;
    }
    return notif;
  }
}

export default new NativeNotifications();
