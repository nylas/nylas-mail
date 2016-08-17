import {Actions} from 'nylas-exports'
import {ipcRenderer} from 'electron'

/**
 * We want to make sure that people have installed the app in a
 * reasonable location.
 *
 * On the Mac, you can accidentally run the app from the DMG. If you do
 * this, it will no longer auto-update. It's also common for Mac users to
 * leave their app in the /Downloads folder (which frequently gets
 * erased!).
 */

let unlisten = () => {}

function onNotificationActionTaken({action}) {
  if (action.id === "verify-install:dont-ask-again") {
    NylasEnv.config.set("asksAboutAppMove", 5)
  } else if (action.id === "verify-install:do-not-move") {
    const numAsks = NylasEnv.config.get("asksAboutAppMove") || 0
    NylasEnv.config.set("asksAboutAppMove", numAsks + 1)
  } else if (action.id === "verify-install:move-to-applications") {
    ipcRenderer.send("move-to-applications")
  }
}

export function activate() {
  unlisten = Actions.notificationActionTaken.listen(onNotificationActionTaken)

  if (NylasEnv.inDevMode() || NylasEnv.inSpecMode()) { return; }

  if (process.platform !== "darwin") { return; }

  const appRe = /Applications/gi;
  if (appRe.test(process.argv[0])) { return; }

  // If we're in Volumes, that means we've launched from the DMG. This
  // is unsupported. We should optimistically move.
  const volTest = /Volumes/gi;
  if (volTest.test(process.argv[0])) {
    ipcRenderer.send("move-to-applications");
    return;
  }

  const numAsks = NylasEnv.config.get("asksAboutAppMove")
  if (numAsks >= 5) return;

  const actions = []
  if (numAsks >= 1) {
    actions.push({
      label: "Don't ask again",
      dismisses: true,
      id: 'verify-install:dont-ask-again',
    })
  }

  const re = /(^.*?\.app)/i;
  let enclosingFolder = (re.exec(process.argv[0]) || [])[0].split("/");
  enclosingFolder = enclosingFolder[enclosingFolder.length - 2]

  let msg = `I can move myself to your Applications folder if you'd like.`
  if (enclosingFolder) {
    msg += ` This will keep your ${enclosingFolder} folder uncluttered.`
  }

  Actions.postNotification({
    type: 'info',
    tag: 'app-update',
    sticky: true,
    message: msg,
    icon: 'fa-flag',
    actions: actions.concat([
      {
        label: "Do Not Move",
        dismisses: true,
        id: 'verify-install:do-not-move',
      },
      {
        "label": "Move to Applications Folder",
        "dismisses": true,
        "default": true,
        "id": 'verify-install:move-to-applications',
      },
    ]),
  });
}

export function deactivate() {
  unlisten()
}
