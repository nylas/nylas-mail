React = require 'react'
_ = require 'underscore-plus'
{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"

###
Public: InjectedComponent makes it easy to include dynamically registered
components inside of your React render method. Rather than explicitly render
a component, such as a `<Composer>`, you can use InjectedComponent:

```
<InjectedComponent name="Composer" draftId={123} />
```

InjectedComponent will look up the component registered with that name in the
{ComponentRegistry} and render it, passing any additional props, like `draftId` along.

InjectedComponent monitors the ComponentRegistry for changes. If a new component
is registered for the name `Composer`, InjectedComponent will swap it in.

If no matching component is found, the InjectedComponent renders an empty div.
###
class InjectedComponent extends React.Component
  @displayName: 'InjectedComponent'

  ###
  Public: React `props` supported by InjectedComponent:
  
   - `name` The {String} name of the component to display. Should be a name passed to the {ComponentRegistry} when registering a component.
  ###
  @propTypes:
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