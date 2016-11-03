import pathwatcher from 'pathwatcher';
import ReactTestUtils from 'react-addons-test-utils';

class MasterAfterEach {
  setup(loadSettings, afterEach) {
    const styleElementsToRestore = NylasEnv.styles.getSnapshot();

    afterEach(() => {
      NylasEnv.packages.deactivatePackages();
      NylasEnv.menu.template = [];

      if (NylasEnv.state) {
        delete NylasEnv.state.packageStates;
      }

      if (!window.debugContent) {
        document.getElementById('jasmine-content').innerHTML = '';
      }
      ReactTestUtils.unmountAll();

      jasmine.unspy(NylasEnv, 'saveSync');
      this.ensureNoPathSubscriptions();

      NylasEnv.styles.restoreSnapshot(styleElementsToRestore);

      waits(0);
    }); // yield to ui thread to make screen update more frequently
  }

  ensureNoPathSubscriptions() {
    const watchedPaths = pathwatcher.getWatchedPaths();
    pathwatcher.closeAllWatchers();
    if (watchedPaths.length > 0) {
      throw new Error(`Leaking subscriptions for paths: ${watchedPaths.join(", ")}`);
    }
  }
}

export default new MasterAfterEach()
