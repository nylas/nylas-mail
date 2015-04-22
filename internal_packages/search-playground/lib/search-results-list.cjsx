_ = require 'underscore-plus'
React = require 'react'
PlaygroundActions = require './playground-actions'
{ListTabular, MultiselectList, Flexbox} = require 'ui-components'
{timestamp, subject} = require './formatting-utils'
{Utils,
 Thread,
 WorkspaceStore,
 NamespaceStore} = require 'inbox-exports'

RelevanceStore = require './relevance-store'
SearchStore = require './search-store'

Relevance = React.createClass
  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unlisten = RelevanceStore.listen @_onUpdate, @

  componentWillUnmount: ->
    @unlisten() if @unlisten

  render: ->
    <div onClick={@_onClick} style={backgroundColor:'#ccc', padding:3, borderRadius:3, textAlign:'center', width:50}>
      {@state.relevance}
    </div>

  _onClick: (event) ->
    PlaygroundActions.setRankNext(@props.threadId)
    event.stopPropagation()

  _onUpdate: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    relevance: RelevanceStore.valueForId(@props.threadId) ? '-'


module.exports =
SearchResultsList = React.createClass
  displayName: 'SearchResultsList'

  componentWillMount: ->
    c2 = new ListTabular.Column
      name: "Name"
      width: 200
      resolver: (thread) ->
        list = thread.participants
        return [] unless list and list instanceof Array
        me = NamespaceStore.current().emailAddress
        list = _.reject list, (p) -> p.email is me
        list = _.map list, (p) -> if p.name and p.name.length then p.name else p.email
        list = list.join(', ')
        <span>{list}</span>

    c3 = new ListTabular.Column
      name: "Message"
      flex: 4
      resolver: (thread) ->
        attachments = []
        if thread.hasTagId('attachment')
          attachments = <div className="thread-icon thread-icon-attachment"></div>
        <span className="details">
          <span className="subject">{subject(thread.subject)}</span>
          <span className="snippet">{thread.snippet}</span>
          {attachments}
        </span>

    c4 = new ListTabular.Column
      name: "Date"
      resolver: (thread) ->
        <span className="timestamp">{timestamp(thread.lastMessageTimestamp)}</span>

    c5 = new ListTabular.Column
      name: "Relevance"
      resolver: (thread) ->
        <Relevance threadId={thread.id} />

    @columns = [c2, c3, c4, c5]
    @commands = {}

  render: ->
    <MultiselectList
      dataStore={SearchStore}
      columns={@columns}
      itemPropsProvider={ -> {} }
      commands={@commands}
      className="thread-list"
      collection="thread" />

