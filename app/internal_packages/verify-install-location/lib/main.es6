import { moveToApplications } from 'electron-lets-move';

/**
 * We want to make sure that people have installed the app in a
 * reasonable location.
 *
 * On the Mac, you can accidentally run the app from the DMG. If you do
 * this, it will no longer auto-update. It's also common for Mac users to
 * leave their app in the /Downloads folder (which frequently gets
 * erased!).
 */
export function activate() {
  if (AppEnv.inDevMode() || AppEnv.inSpecMode()) {
    return;
  }

  if (AppEnv.config.get('askedAboutAppMove')) {
    return;
  }

  moveToApplications(function(err, moved) {
    if (err) {
      // log error, something went wrong whilst moving the app.
    }
    if (!moved) {
      // the user asked not to move the app, it's up to the parent application
      // to store this information and not hassle them again.
      AppEnv.config.set('askedAboutAppMove', true);
    }
  });
}

export function deactivate() {}
