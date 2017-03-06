import DeltaConnectionStore from './delta-connection-store'

export function activate() {
  DeltaConnectionStore.activate()
  window.$n.DeltaConnectionStore = DeltaConnectionStore
}

export function deactivate() {
  DeltaConnectionStore.deactivate()
}
