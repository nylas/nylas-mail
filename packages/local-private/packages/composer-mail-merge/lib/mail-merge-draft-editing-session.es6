import NylasStore from 'nylas-store'
import * as TableStateReducers from './table-state-reducers'
import * as TokenStateReducers from './token-state-reducers'
import * as SelectionStateReducers from './selection-state-reducers'
import * as WorkspaceStateReducers from './workspace-state-reducers'
import {ActionNames, PLUGIN_ID, DEBUG} from './mail-merge-constants'


const sessions = new Map()

function computeNextState({name, args = []}, previousState = {}, reducers = []) {
  if (reducers.length === 0) {
    return previousState
  }
  return reducers.reduce((state, reducer) => {
    if (reducer[name]) {
      const reduced = reducer[name](previousState, ...args)
      return {...state, ...reduced}
    }
    return state
  }, previousState)
}

/**
 * MailMergeDraftEditingSession instances hold the entire state for the Mail Merge
 * plugin for a given draft, as a single state tree. Sessions trigger when any changes
 * on the state tree occur.
 *
 * Mail Merge state for a draft can be modified by dispatching actions on a session instance.
 * Available actions are defined by `MailMergeConstants.ActionNames`.
 * Actions are dispatched by calling the action on a session as a method:
 * ```
 *  session.addColumn()
 * ```
 *
 * Internally, the session acts as a Proxy which forwards action calls into any
 * registered reducers, and merges the resulting state from calling the action
 * on each reducer to compute the new state tree. Registered reducers are
 * currently hardcoded in this class.
 *
 * A session instance also acts as a proxy for the corresponding `DraftEditingSession`,
 * instance, and forwards to it any changes that need to be persisted on the draft object
 *
 * @class MailMergeDraftEditingSession
 */
export class MailMergeDraftEditingSession extends NylasStore {

  constructor(session, reducers) {
    super()
    this._session = session
    this._reducers = reducers || [
      TableStateReducers,
      TokenStateReducers,
      SelectionStateReducers,
      WorkspaceStateReducers,
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

  draftSession() {
    return this._session
  }

  initializeState(draft = this._session.draft()) {
    const savedMetadata = draft.metadataForPluginId(PLUGIN_ID)
    const shouldLoadSavedData = (
      savedMetadata &&
      savedMetadata.tableDataSource &&
      savedMetadata.tokenDataSource
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

  dispatch(action, prevState = this._state) {
    const nextState = computeNextState(action, prevState, this._reducers)
    if (DEBUG && action.debug !== false) {
      console.log('--> action', action.name)
      console.dir(action)
      console.log('--> prev state')
      console.dir(prevState)
      console.log('--> new state')
      console.dir(nextState)
    }
    return nextState
  }

  actionHandler(actionName) {
    return (...args) => {
      this._state = this.dispatch({name: actionName, args})

      // Defer calling `saveToSession` to make sure our state changes are triggered
      // before the draft changes
      this.trigger()
      setImmediate(this.saveToDraftSession)
    }
  }

  saveToDraftSession = () => {
    // TODO
    // - What should we save in metadata?
    //   - The entire table data?
    //   - A reference to a statically hosted file?
    //   - Attach csv as a file to the "base" or "template" draft?
    const {tokenDataSource, tableDataSource} = this._state
    const draftChanges = this.dispatch({name: 'toDraftChanges', args: [this._state], debug: false}, this.draft())
    const serializedState = this.dispatch({name: 'toJSON', debug: false}, {tokenDataSource, tableDataSource})

    this._session.changes.add(draftChanges)
    this._session.changes.addPluginMetadata(PLUGIN_ID, serializedState)
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
