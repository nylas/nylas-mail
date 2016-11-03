/* eslint global-require: 0 */
let MacNotifierNotification = null;
if (process.platform === 'darwin') {
  try {
    MacNotifierNotification = require('node-mac-notifier');
  } catch (err) {
    console.error("node-mac-notifier (a platform-specific optionalDependency) was not installed correctly! Check the Travis build log for errors.")
  }
}

class NativeNotifications {
  displayNotification({title, subtitle, body, tag, canReply, onActivate} = {}) {
    let notif = null;

    if (MacNotifierNotification) {
      notif = new MacNotifierNotification(title, {
        bundleId: 'com.nylas.nylas-mail',
        canReply: canReply,
        subtitle: subtitle,
        body: body,
        id: tag,
      });
      notif.addEventListener('reply', ({response}) => {
        onActivate({response, activationType: 'replied'});
      });
      notif.addEventListener('click', () => {
        onActivate({response: null, activationType: 'clicked'});
      });
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

export default new NativeNotifications()
