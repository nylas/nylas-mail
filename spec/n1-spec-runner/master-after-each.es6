import pathwatcher from 'pathwatcher';
import ReactTestUtils from 'react-addons-test-utils';
// TODO the local-sync package should be moved as part of nylas-mail core,
// instead of being a separate package
import {destroyTestDatabase} from '../../internal_packages/local-sync/spec/helpers'

class MasterAfterEach {
  setup(loadSettings, afterEach) {
    const styleElementsToRestore = NylasEnv.styles.getSnapshot();

    const self = this
    afterEach(function masterAfterEach() {
      destroyTestDatabase()
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
      self.ensureNoPathSubscriptions();

      NylasEnv.styles.restoreSnapshot(styleElementsToRestore);

      this.removeAllSpies();
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
