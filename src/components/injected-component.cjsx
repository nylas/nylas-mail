React = require 'react'
_ = require 'underscore'
UnsafeComponent = require './unsafe-component'
InjectedComponentLabel = require './injected-component-label'

{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "nylas-exports"

###
Public: InjectedComponent makes it easy to include dynamically registered
components inside of your React render method. Rather than explicitly render
a component, such as a `<Composer>`, you can use InjectedComponent:

```coffee
<InjectedComponent matching={role:"Composer"} exposedProps={draftId:123} />
```

InjectedComponent will look up the component registered with that role in the
{ComponentRegistry} and render it, passing the exposedProps (`draftId={123}`) along.

InjectedComponent monitors the ComponentRegistry for changes. If a new component
is registered that matches the descriptor you provide, InjectedComponent will refresh.

If no matching component is found, the InjectedComponent renders an empty div.

Section: Component Kit
###
class InjectedComponent extends React.Component
  @displayName: 'InjectedComponent'

  ###
  Public: React `props` supported by InjectedComponent:

   - `matching` Pass an {Object} with ComponentRegistry descriptors.
      This set of descriptors is provided to {ComponentRegistry::findComponentsForDescriptor}
      to retrieve the component that will be displayed.

   - `className` (optional) A {String} class name for the containing element.

   - `exposedProps` (optional) An {Object} with props that will be passed to each
      item rendered into the set.

  ###
  @propTypes:
    matching: React.PropTypes.object.isRequired
    className: React.PropTypes.string
    exposedProps: React.PropTypes.object

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())

  componentWillUnmount: =>
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) =>
    if not _.isEqual(newProps.matching, @props?.matching)
      @setState(@_getStateFromStores(newProps))

  render: =>
    return <div></div> unless @state.component

    exposedProps = @props.exposedProps ? {}
    className = @props.className ? ""
    className += "registered-region-visible" if @state.visible

    component = @state.component

    if component.containerRequired is false
      element = <component ref="inner" key={component.displayName} {...exposedProps} />
    else
      element = <UnsafeComponent ref="inner" component={component} key={component.displayName} {...exposedProps} />

    if @state.visible
      <div className={className}>
        {element}
        <InjectedComponentLabel matching={@props.matching} {...exposedProps} />
        <span style={clear:'both'}/>
      </div>
    else
      <div className={className}>
        {element}
      </div>

  focus: =>
    # Not forwarding event - just a method call
    @refs.inner.focus() if @refs.inner.focus?

  blur: =>
    # Not forwarding an event - just a method call
    @refs.inner.blur() if @refs.inner.blur?

  _getStateFromStores: (props) =>
    props ?= @props

    components = ComponentRegistry.findComponentsMatching(props.matching)
    if components.length > 1
      console.warn("There are multiple components available for \
                   #{JSON.stringify(props.matching)}. <InjectedComponent> is \
                   only rendering the first one.")

    component: components[0]
    visible: ComponentRegistry.showComponentRegions()

module.exports = InjectedComponent
