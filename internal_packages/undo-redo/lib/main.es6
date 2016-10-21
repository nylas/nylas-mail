import {ComponentRegistry, WorkspaceStore} from 'nylas-exports'
import UndoRedoThreadListToast from './undo-redo-thread-list-toast'
import UndoSendStore from './undo-send-store';
import UndoSendToast from './undo-send-toast';


export function activate() {
  UndoSendStore.activate()
  ComponentRegistry.register(UndoSendToast, {
    location: WorkspaceStore.Sheet.Global.Footer,
  });
  if (NylasEnv.isMainWindow()) {
    ComponentRegistry.register(UndoRedoThreadListToast, {
      location: WorkspaceStore.Location.ThreadList,
    })
  }
}

export function deactivate() {
  UndoSendStore.deactivate()
  ComponentRegistry.unregister(UndoSendToast);
  if (NylasEnv.isMainWindow()) {
    ComponentRegistry.unregister(UndoRedoThreadListToast)
  }
}
