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
<InjectedComponent matching={role:"Composer"} exposedProps={draftClientId:123} />
```

InjectedComponent will look up the component registered with that role in the
{ComponentRegistry} and render it, passing the exposedProps (`draftClientId={123}`) along.

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

   - `onComponentDidRender` (optional) Callback that will be called when the injected component
      is successfully rendered onto the DOM.

   - `className` (optional) A {String} class name for the containing element.

   - `exposedProps` (optional) An {Object} with props that will be passed to each
      item rendered into the set.

   - `fallback` (optional) A {Component} to default to in case there are no matching
     components in the ComponentRegistry

   - `requiredMethods` (options) An {Array} with a list of methods that should be
     implemented by the registered component instance. If these are not implemented,
     an error will be thrown.

  ###
  @propTypes:
    matching: React.PropTypes.object.isRequired
    className: React.PropTypes.string
    exposedProps: React.PropTypes.object
    fallback: React.PropTypes.func
    onComponentDidRender: React.PropTypes.func
    requiredMethods: React.PropTypes.arrayOf(React.PropTypes.string)

  @defaultProps:
    requiredMethods: []
    onComponentDidRender: ->

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @_verifyRequiredMethods()
    @_setRequiredMethods(@props.requiredMethods)

  componentDidMount: =>
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())
    @props.onComponentDidRender() if @state.component?.containerRequired is false

  componentWillUnmount: =>
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) =>
    if not _.isEqual(newProps.matching, @props?.matching)
      @setState(@_getStateFromStores(newProps))

  componentDidUpdate: =>
    @_setRequiredMethods(@props.requiredMethods)
    @props.onComponentDidRender() if @state.component?.containerRequired is false

  render: =>
    return <div></div> unless @state.component

    exposedProps = @props.exposedProps ? {}
    className = @props.className ? ""
    className += " registered-region-visible" if @state.visible

    component = @state.component
    if component.containerRequired is false
      element = <component ref="inner" key={component.displayName} {...exposedProps} />
    else
      element = (
        <UnsafeComponent
          ref="inner"
          key={component.displayName}
          component={component}
          onComponentDidRender={@props.onComponentDidRender}
          {...exposedProps} />
      )

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
    @_runInnerDOMMethod('focus')

  blur: =>
    @_runInnerDOMMethod('blur')

  # Private: Attempts to run the DOM method, ie 'focus', on
  # 1. Any implementation provided by the inner component
  # 2. Any native implementation provided by the DOM
  # 3. Ourselves, so that the method always has /some/ effect.
  #
  _runInnerDOMMethod: (method) =>
    target = null
    if @refs.inner and @refs.inner[method]
      target = @refs.inner
    else if @refs.inner
      target = React.findDOMNode(@refs.inner)
    else
      target = React.findDOMNode(@)

    target[method]?()

  _setRequiredMethods: (methods) =>
    methods.forEach (method) =>
      Object.defineProperty(@, method,
        configurable: true
        enumerable: true
        get: =>
          if @refs.inner instanceof UnsafeComponent
            @refs.inner.injected[method]?.bind(@refs.inner.injected)
          else
            @refs.inner[method]?.bind(@refs.inner)
      )

  _verifyRequiredMethods: =>
    if @state.component?
      component = @state.component
      @props.requiredMethods.forEach (method) =>
        isMethodDefined = @state.component.prototype[method]?
        unless isMethodDefined
          throw new Error(
            "#{component.name} must implement method `#{method}` when registering
            for #{JSON.stringify(@props.matching)}"
          )

  _getStateFromStores: (props) =>
    props ?= @props

    components = ComponentRegistry.findComponentsMatching(props.matching)
    if components.length > 1
      console.warn("There are multiple components available for \
                   #{JSON.stringify(props.matching)}. <InjectedComponent> is \
                   only rendering the first one.")
    component = if components.length is 0
      @props.fallback
    else
      components[0]

    component: component
    visible: ComponentRegistry.showComponentRegions()

module.exports = InjectedComponent
