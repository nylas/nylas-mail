import {SystemStartService, WorkspaceStore, ComponentRegistry} from 'nylas-exports';
import OnboardingRoot from './onboarding-root';

export function activate() {
  WorkspaceStore.defineSheet('Main', {root: true}, {list: ['Center']});

  ComponentRegistry.register(OnboardingRoot, {
    location: WorkspaceStore.Location.Center,
  });

  const accounts = NylasEnv.config.get('nylas.accounts') || [];

  if (accounts.length === 0) {
    const startService = new SystemStartService();
    startService.checkAvailability().then((available) => {
      if (!available) {
        return;
      }
      startService.doesLaunchOnSystemStart().then((launchesOnStart) => {
        if (!launchesOnStart) {
          startService.configureToLaunchOnSystemStart();
        }
      });
    });
  }
}

export function deactivate() {

}

export function serialize() {

}
