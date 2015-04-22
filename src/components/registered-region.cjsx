React = require 'react'
_ = require 'underscore-plus'
{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"

module.exports =
RegisteredRegion = React.createClass
  displayName: 'RegisteredRegion'

  propTypes:
    location: React.PropTypes.string.isRequired
    style: React.PropTypes.object
    className: React.PropTypes.string
    children: React.PropTypes.array

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())

  componentWillUnmount: ->
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) ->
    if newProps.location isnt @props?.location
      @setState(@_getStateFromStores(newProps))

  render: ->
    props = _.omit(@props, _.keys(@constructor.propTypes))

    elements = (@state.components ? []).map ({view, name}) ->
      <view key={name} {...props} />

    className = @props.className
    if @state.visible
      className += " registered-region-visible"
      propDescriptions = []
      for key, val of props
        propDescriptions.push("#{key}:<#{val?.constructor?.name ? typeof(val)}>")
      description = "#{@props.location}"
      description += " (#{propDescriptions.join(', ')})" if propDescriptions.length > 0
      elements.splice(0,0,<span className="name">{description}</span>)
      elements.push(<span style={clear:'both'}/>)

    <span style={@props.style}
         className={className}
         regionName={@props.location}>
        {elements}
        {@props.children ? []}
    </span>

  _getStateFromStores: (props) ->
    props ?= @props

    components: ComponentRegistry.findAllByRole(@props.location)
    visible: ComponentRegistry.showComponentRegions()
