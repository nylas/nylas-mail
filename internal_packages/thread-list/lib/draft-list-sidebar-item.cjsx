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
      unread = <div className="unread item-count-box">{@state.count}</div>

    <div className={classSet} onClick={@_onClick}>
      <div className="icon"><RetinaImg name={'drafts.png'} mode={RetinaImg.Mode.ContentIsMask} /></div>
      <div className="name"> {@props.item.name}</div>
      {unread}
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(@props.item)

module.exports = DraftListSidebarItem
