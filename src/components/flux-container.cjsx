React = require 'react'
_ = require 'underscore'

class FluxContainer extends React.Component
  @displayName: 'FluxContainer'
  @propTypes:
    children: React.PropTypes.element
    stores: React.PropTypes.array.isRequired
    getStateFromStores: React.PropTypes.func.isRequired

  constructor: (@props) ->
    @_unlisteners = []

  componentWillMount: ->
    @setState(@props.getStateFromStores())

  componentDidMount: ->
    @setupListeners()

  componentWillReceiveProps: (nextProps) ->
    @setState(nextProps.getStateFromStores())
    @setupListeners(nextProps)

  setupListeners: (props = @props) ->
    unlisten() for unlisten in @_unlisteners
    @_unlisteners = props.stores.map (store) =>
      store.listen => @setState(props.getStateFromStores())

  componentWillUnmount: ->
    unlisten() for unlisten in @_unlisteners
    @_unlisteners = []

  render: ->
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    React.cloneElement(@props.children, _.extend({}, otherProps, @state))

module.exports = FluxContainer
