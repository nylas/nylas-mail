React = require 'react'
_ = require 'underscore'
classNames = require 'classnames'
{Actions, Utils, WorkspaceStore, DraftCountStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class DraftListSidebarItem extends React.Component
  @displayName: 'DraftListSidebarItem'

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @unsubscribe = DraftCountStore.listen(@_onCountChanged)

  componentWillUnmount: =>
    @unsubscribe()

  getStateFromStores: =>
    count: DraftCountStore.count()

  _onCountChanged: =>
    @setState(@getStateFromStores())

  render: =>
    classSet = classNames
      'item': true
      'selected': @props.select

    unread = []
    if @state.count > 0
      unread = <div className="count item-count-box">{@state.count}</div>

    <div className={classSet} onClick={@_onClick}>
      {unread}
      <div className="icon"><RetinaImg name={'drafts.png'} mode={RetinaImg.Mode.ContentIsMask} /></div>
      <div className="name"> Drafts</div>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Drafts)

module.exports = DraftListSidebarItem
