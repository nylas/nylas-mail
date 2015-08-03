_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
{RetinaImg} = require 'nylas-component-kit'
{DatabaseView,
 NamespaceStore,
 NylasAPI,
 WorkspaceStore} = require 'nylas-exports'

EmptyMessages = [{
  "body":"The pessimist complains about the wind.\nThe optimist expects it to change.\nThe realist adjusts the sails."
  "byline": "- William Arthur Ward"
},{
  "body":"The best and most beautiful things in the world cannot be seen or even touched - they must be felt with the heart."
  "byline": "- Hellen Keller"
},{
  "body":"Believe you can and you're halfway there."
  "byline": "- Theodore Roosevelt"
},{
  "body":"Don't judge each day by the harvest you reap but by the seeds that you plant."
  "byline": "- Robert Louis Stevenson"
}]

class ContentGeneric extends React.Component
  render: ->
    <div className="generic">
      <div className="message">
        {@props.messageOverride ? "No threads to display."}
      </div>
    </div>

class ContentQuotes extends React.Component
  @displayName = 'Quotes'

  constructor: (@props) ->
    @state = {}

  componentDidMount: ->
    # Pick a random quote using the day as a seed. I know not all months have
    # 31 days - this is good enough to generate one quote a day at random!
    d = new Date()
    r = d.getDate() + d.getMonth() * 31
    message = EmptyMessages[r % EmptyMessages.length]
    @setState(message: message)

  render: ->
    <div className="quotes">
      {@_renderMessage()}
      <RetinaImg mode={RetinaImg.Mode.ContentLight} url="nylas://thread-list/assets/blank-bottom-left@2x.png" className="bottom-left"/>
      <RetinaImg mode={RetinaImg.Mode.ContentLight} url="nylas://thread-list/assets/blank-top-left@2x.png" className="top-left"/>
      <RetinaImg mode={RetinaImg.Mode.ContentLight} url="nylas://thread-list/assets/blank-bottom-right@2x.png" className="bottom-right"/>
      <RetinaImg mode={RetinaImg.Mode.ContentLight} url="nylas://thread-list/assets/blank-top-right@2x.png" className="top-right"/>
    </div>

  _renderMessage: ->
    if @props.messageOverride
      <div className="message">{@props.messageOverride}</div>
    else
      <div className="message">
        {@state.message?.body}
        <div className="byline">
          {@state.message?.byline}
        </div>
      </div>


class EmptyState extends React.Component
  @displayName = 'EmptyState'
  @propTypes =
    visible: React.PropTypes.bool.isRequired
    dataView: React.PropTypes.object

  constructor: (@props) ->
    @state =
      layoutMode: WorkspaceStore.layoutMode()
      syncing: false
      active: false

  componentDidMount: ->
    @_unlisteners = []
    @_unlisteners.push WorkspaceStore.listen(@_onChange, @)
    @_unlisteners.push NamespaceStore.listen(@_onNamespacesChanged, @)
    @_onNamespacesChanged()

  shouldComponentUpdate: (nextProps, nextState) ->
    # Avoid deep comparison of dataView, which is a very complex object
    return true if nextProps.visible isnt @props.visible
    return true if nextProps.dataView isnt @props.dataView
    return not _.isEqual(nextState, @state)

  _onNamespacesChanged: ->
    namespace = NamespaceStore.current()
    @_worker = NylasAPI.workerForNamespace(namespace)
    @_workerUnlisten() if @_workerUnlisten
    @_workerUnlisten = @_worker.listen(@_onChange, @)
    @setState(syncing: @_worker.busy())

  componentWillUnmount: ->
    unlisten() for unlisten in @_unlisteners
    @_workerUnlisten() if @_workerUnlisten

  componentDidUpdate: ->
    if @props.visible and not @state.active
      @setState(active:true)

  componentWillReceiveProps: (newProps) ->
    if newProps.visible is false
      @setState(active:false)

  render: ->
    ContentComponent = ContentGeneric
    messageOverride = null

    if @props.dataView instanceof DatabaseView
      if @state.layoutMode is 'list'
        ContentComponent = ContentQuotes
      if @state.syncing
        messageOverride = "Please wait while we prepare your mailbox."

    classes = classNames
      'empty-state': true
      'visible': @props.visible
      'active': @state.active

    <div className={classes}>
      <ContentComponent messageOverride={messageOverride}/>
    </div>

  _onChange: ->
    @setState
      layoutMode: WorkspaceStore.layoutMode()
      syncing: @_worker.busy()


module.exports = EmptyState
