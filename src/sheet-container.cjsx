React = require 'react'
SheetStore = require './sheet-store'
{Actions,ComponentRegistry} = require "inbox-exports"
Flexbox = require './components/flexbox.cjsx'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup

ToolbarSpacer = React.createClass
  render: ->
    <div style={flex: 1, order:50}></div>

Toolbar = React.createClass
  propTypes:
    type: React.PropTypes.string.isRequired

  getInitialState: ->
    @_getComponentRegistryState()

  componentDidMount: ->
    @unlistener = ComponentRegistry.listen (event) =>
      @setState(@_getComponentRegistryState())

  componentWillUnmount: ->
    @unlistener() if @unlistener

  render: ->
    <div className="toolbar" name={@props.type}>
      <Flexbox direction="row">
        {@_buttonComponents()}
        <ToolbarSpacer />
      </Flexbox>
    </div>

  _buttonComponents: ->
    @state.items.map (item) =>
      <item {...@props} />

  _getComponentRegistryState: ->
    globalItems = ComponentRegistry.findAllViewsByRole "Global:Toolbar"
    typeItems = ComponentRegistry.findAllViewsByRole "#{@props.type}:Toolbar"

    items: [].concat(globalItems, typeItems)

Footer = React.createClass
  getInitialState: ->
    @_getComponentRegistryState()

  componentDidMount: ->
    @unlistener = ComponentRegistry.listen (event) =>
      @setState(@_getComponentRegistryState())

  componentWillUnmount: ->
    @unlistener() if @unlistener

  render: ->
    <div className="footer">
      <Flexbox direction="row">
        {@_footerComponents()}
      </Flexbox>
    </div>

  _footerComponents: ->
    @state.items.map (item) =>
      <item {...@props} />

  _getComponentRegistryState: ->
    items: ComponentRegistry.findAllViewsByRole "Global:Footer"


module.exports =
SheetContainer = React.createClass

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = SheetStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    type = @state.stack?[@state.stack - 1]?.props.type or 'none'

    <Flexbox direction="column">
      <div style={order:0} className="toolbar-container">
        <ReactCSSTransitionGroup transitionName="toolbar">
          <Toolbar type={type} />
        </ReactCSSTransitionGroup>
      </div>
      <div style={order:1, flex: 1, position:'relative'}>
        <ReactCSSTransitionGroup transitionName="sheet-stack">
          {@state.stack}
        </ReactCSSTransitionGroup>
      </div>
      <div style={order:2} className="footer-container">
        <Footer />
      </div>
    </Flexbox>

  _onStoreChange: ->
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    stack: SheetStore.stack()

