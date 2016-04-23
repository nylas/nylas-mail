import NylasStore from 'nylas-store'
import * as TableDataReducer from './table-data-reducer'
import * as WorkspaceDataReducer from './workspace-data-reducer'
import {ActionNames, PLUGIN_ID, DEBUG} from './mail-merge-constants'


const sessions = new Map()

function computeNextState({name, args = []}, currentState = {}, reducers = []) {
  if (reducers.length === 0) {
    return currentState
  }
  return reducers.reduce((state, reducer) => {
    const reduced = (reducer[name] || () => state)(state, ...args)
    return {...state, ...reduced}
  }, currentState)
}

export class MailMergeDraftEditingSession extends NylasStore {

  constructor(session) {
    super()
    this._session = session
    this._reducers = [
      TableDataReducer,
      WorkspaceDataReducer,
    ]
    this._state = {}
    this.initializeState()
    this.initializeActionHandlers()
  }

  get state() {
    return this._state
  }

  draft() {
    return this._session.draft()
  }

  initializeState() {
    const draft = this._session.draft()
    const savedMetadata = draft.metadataForPluginId(PLUGIN_ID)
    const shouldLoadSavedData = (
      savedMetadata &&
      savedMetadata.tableData &&
      savedMetadata.linkedFields
    )
    const action = {name: 'initialState'}
    if (shouldLoadSavedData) {
      const loadedState = this.dispatch({name: 'fromJSON'}, savedMetadata)
      this._state = this.dispatch(action, loadedState)
    } else {
      this._state = this.dispatch(action)
    }
  }

  initializeActionHandlers() {
    ActionNames.forEach((actionName) => {
      // TODO ES6 Proxies would be nice here
      this[actionName] = this.actionHandler(actionName).bind(this)
    })
  }

  dispatch(action, initialState = this._state) {
    const newState = computeNextState(action, initialState, this._reducers)
    if (DEBUG) {
      console.log('--> action', action.name)
      console.dir(action)
      console.log('--> prev state')
      console.dir(initialState)
      console.log('--> new state')
      console.dir(newState)
    }
    return newState
  }

  actionHandler(actionName) {
    return (...args) => {
      this._state = this.dispatch({name: actionName, args})

      // Defer calling `saveToSession` to make sure our state changes are triggered
      // before the draft changes
      this.trigger()
      setImmediate(this.saveToDraftSession.bind(this))
    }
  }

  saveToDraftSession() {
    // TODO
    // - What should we save in metadata?
    //   - The entire table data?
    //   - A reference to a statically hosted file?
    //   - Attach csv as a file to the "base" or "template" draft?
    // const draft = this._session.draft()
    const {linkedFields, tableData} = this._state
    const draftChanges = this.dispatch({name: 'toDraft', args: [this._state]}, {})
    const serializedState = this.dispatch({name: 'toJSON'}, {linkedFields, tableData})

    this._session.changes.add(draftChanges)
    this._session.changes.addPluginMetadata(PLUGIN_ID, serializedState)
    this._session.changes.commit()
    // TODO
    // Do I need to call this._session.changes.commit?
  }
}

export function mailMergeSessionForDraft(draftId, draftSession) {
  if (sessions.has(draftId)) {
    return sessions.get(draftId)
  }
  if (!draftSession) {
    return null
  }
  const sess = new MailMergeDraftEditingSession(draftSession)
  sessions.set(draftId, sess)
  return sess
}
