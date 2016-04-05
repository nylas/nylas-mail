_ = require 'underscore'
_str = require 'underscore.string'
classNames = require 'classnames'
React = require 'react'
{Actions, AccountStore, NylasSyncStatusStore} = require 'nylas-exports'

class InitialSyncActivity extends React.Component
  @displayName: 'InitialSyncActivity'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_usub = NylasSyncStatusStore.listen @_onDataChanged

  componentWillUnmount: =>
    @_usub?()

  _onDataChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    sync: NylasSyncStatusStore.state()

  render: =>
    count = 0
    fetched = 0
    totalProgress = 0
    incomplete = 0
    error = null

    for acctId, state of @state.sync
      for model, modelState of state
        incomplete += 1 unless modelState.complete
        error ?= modelState.error
        if modelState.count
          count += modelState.count / 1
          fetched += modelState.fetched / 1

    totalProgress = (fetched / count) * 100 if count > 0

    classSet = classNames
      'item': true
      'expanded-sync': @state.expandedSync

    if incomplete is 0
      return false
    else if error
      <div className={classSet} key="initial-sync">
        <div className="inner">An error occurred while syncing your mailbox. Sync will resume in a moment&hellip;
          <div className="btn" style={marginTop:10} onClick={@_onTryAgain}>Try Again Now</div>
        </div>
        {@_expandedSyncState()}
      </div>
    else
      <div className={classSet} key="initial-sync" onClick={=> @setState expandedSync: !@state.expandedSync}>
        {@_renderProgressBar(totalProgress)}
        <div className="inner">Syncing your mailbox&hellip;</div>
        {@_expandedSyncState()}
      </div>

  _expandedSyncState: ->
    accounts = []
    for acctId, state of @state.sync
      account = _.findWhere(AccountStore.accounts(), id: acctId)
      continue unless account

      modelStates = _.map state, (modelState, model) =>
        @_renderModelProgress(model, modelState, 100)

      accounts.push(
        <div className="account inner" key={acctId}>
          <h2>{account.emailAddress}</h2>
          {modelStates}
        </div>
      )

    <div className="account-detail-area">
      {accounts}
      <a className="close-expanded" onClick={@_hideExpandedState}>Hide</a>
    </div>

  _hideExpandedState: (event) =>
    event.stopPropagation() # So it doesn't reach the parent's onClick
    event.preventDefault()
    @setState expandedSync: false
    return

  _renderModelProgress: (model, modelState) ->
    if modelState.error
      status = "error"
    else if modelState.complete
      status = "complete"
    else
      status = "busy"
    percent = (+modelState.fetched / +modelState.count) * 100

    <div className="model-progress #{status}" key={model}>
      <h3>{_str.titleize(model)}:</h3>
      {@_renderProgressBar(percent)}
      <div className="amount">{_str.numberFormat(modelState.fetched)} / {_str.numberFormat(modelState.count)}</div>
      <div className="error-text">{modelState.error}</div>
    </div>

  _renderProgressBar: (percent) ->
    <div className="progress-track">
      <div className="progress" style={width: "#{percent}%"}></div>
    </div>

  _onTryAgain: =>
    Actions.retrySync()

module.exports = InitialSyncActivity
