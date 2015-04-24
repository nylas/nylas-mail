React = require 'react'
_ = require 'underscore-plus'
{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"

class InjectedComponent extends React.Component

  @displayName = 'InjectedComponent'
  @propTypes =
    name: React.PropTypes.string.isRequired

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())

  componentWillUnmount: =>
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) =>
    if newProps.name isnt @props?.name
      @setState(@_getStateFromStores(newProps))

  render: =>
    view = @state.component
    return <div></div> unless view
    props = _.omit(@props, _.keys(@constructor.propTypes))

    <view ref="inner" key={name} {...props} />
 
  focus: =>
    # Not forwarding event - just a method call
    @refs.inner.focus() if @refs.inner.focus?
 
  blur: =>
    # Not forwarding an event - just a method call
    @refs.inner.blur() if @refs.inner.blur?

  _getStateFromStores: (props) =>
    props ?= @props
    component: ComponentRegistry.findViewByName(props.name)

module.exports = InjectedComponent