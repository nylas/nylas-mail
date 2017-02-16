React = require 'react'
ReactDOM = require 'react-dom'
_ = require 'underscore'
UnsafeComponent = require './unsafe-component'
InjectedComponentLabel = require('./injected-component-label').default

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
    style: React.PropTypes.object
    requiredMethods: React.PropTypes.arrayOf(React.PropTypes.string)
    onComponentDidChange: React.PropTypes.func

  @defaultProps:
    style: {}
    exposedProps: {}
    requiredMethods: []
    onComponentDidRender: ->
    onComponentDidChange: ->

  constructor: (@props) ->
    @state = @_getStateFromStores()
    @_verifyRequiredMethods()
    @_setRequiredMethods(@props.requiredMethods)

  componentDidMount: =>
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())
    if @state.component?.containerRequired is false
      @props.onComponentDidRender()
      @props.onComponentDidChange()

  componentWillUnmount: =>
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) =>
    if not _.isEqual(newProps.matching, @props?.matching)
      @setState(@_getStateFromStores(newProps))

  componentDidUpdate: (prevProps, prevState) =>
    @_setRequiredMethods(@props.requiredMethods)
    if @state.component?.containerRequired is false
      @props.onComponentDidRender()
      if @state.component isnt prevState.component
        @props.onComponentDidChange()


  render: =>
    return <div></div> unless @state.component

    exposedProps = Object.assign({}, @props.exposedProps, {fallback: @props.fallback})
    className = @props.className ? ""
    className += " registered-region-visible" if @state.visible

    Component = @state.component
    if Component.containerRequired is false
      privateProps = {
        key: Component.displayName,
      }
      if React.Component.isPrototypeOf(Component)
        privateProps.ref = 'inner'
      element = <Component {...privateProps} {...exposedProps} />
    else
      element = (
        <UnsafeComponent
          ref="inner"
          style={@props.style}
          className={className}
          key={Component.displayName}
          component={Component}
          onComponentDidRender={@props.onComponentDidRender}
          {...exposedProps} />
      )

    if @state.visible
      <div className={className} style={@props.style}>
        {element}
        <InjectedComponentLabel matching={@props.matching} {...exposedProps} />
        <span style={clear:'both'}/>
      </div>
    else
      <div className={className} style={@props.style}>
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
  _runInnerDOMMethod: (method, args...) =>
    target = null
    if @refs.inner instanceof UnsafeComponent and @refs.inner.injected[method]?
      target = @refs.inner.injected
    else if @refs.inner and @refs.inner[method]?
      target = @refs.inner
    else if @refs.inner
      target = ReactDOM.findDOMNode(@refs.inner)
    else
      target = ReactDOM.findDOMNode(@)

    if target[method]
      target[method].bind(target)(args...)

  _setRequiredMethods: (methods) =>
    methods.forEach (method) =>
      Object.defineProperty(@, method,
        configurable: true
        enumerable: true
        value: (args...) =>
          @_runInnerDOMMethod(method, args...)
      )

  _verifyRequiredMethods: =>
    if @state.component?
      component = @state.component
      @props.requiredMethods.forEach (method) =>
        isMethodDefined = component.prototype[method]?
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
