import SyncHealthChecker from './sync-health-checker'

export function activate() {
  SyncHealthChecker.start()
}

export function deactivate() {
  SyncHealthChecker.stop()
}
