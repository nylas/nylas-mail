React = require 'react'
_ = require 'underscore-plus'
UnsafeComponent = require './unsafe-component'
Flexbox = require './flexbox'
InjectedComponentLabel = require './injected-component-label'
{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"


###
Public: InjectedComponent makes it easy to include a set of dynamically registered
components inside of your React render method. Rather than explicitly render
an array of buttons, for example, you can use InjectedComponentSet:

```
<InjectedComponentSet className="message-actions"
                  matching={role: 'ThreadActionButton'}
                  exposedProps={thread:@props.thread, message:@props.message}>
```

InjectedComponentSet will look up components registered for the location you provide,
render them inside a {Flexbox} and pass them `exposedProps`. By default, all injected
children are rendered inside {UnsafeComponent} wrappers to prevent third-party code
from throwing exceptions that break React renders.

InjectedComponentSet monitors the ComponentRegistry for changes. If a new component
is registered into the location you provide, InjectedComponentSet will re-render.

If no matching components is found, the InjectedComponent renders an empty span.
###
class InjectedComponentSet extends React.Component
  @displayName: 'InjectedComponentSet'

  ###
  Public: React `props` supported by InjectedComponentSet:

   - `matching` Pass an {Object} with ComponentRegistry descriptors
      This set of descriptors is provided to {ComponentRegistry::findComponentsForDescriptor}
      to retrieve components for display.
   - `className` (optional) A {String} class name for the containing element.
   - `children` (optional) Any React elements rendered inside the InjectedComponentSet
      will always be displayed.
   - `exposedProps` (optional) An {Object} with props that will be passed to each
      item rendered into the set.

   -  Any other props you provide, such as `direction`, `data-column`, etc.
      will be applied to the {Flexbox} rendered by the InjectedComponentSet.
  ###
  @propTypes:
    matching: React.PropTypes.object.isRequired
    children: React.PropTypes.array
    className: React.PropTypes.string
    exposedProps: React.PropTypes.object

  @defaultProps:
    direction: 'row'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_componentUnlistener = ComponentRegistry.listen =>
      @setState(@_getStateFromStores())

  componentWillUnmount: =>
    @_componentUnlistener() if @_componentUnlistener

  componentWillReceiveProps: (newProps) =>
    if newProps.location isnt @props?.location
      @setState(@_getStateFromStores(newProps))

  render: =>
    flexboxProps = _.omit(@props, _.keys(@constructor.propTypes))
    flexboxClassName = @props.className ? ""
    exposedProps = @props.exposedProps ? {}

    elements = @state.components.map (component) ->
      if component.containerRequired is false
        <component key={component.displayName} {...exposedProps} />
      else
        <UnsafeComponent component={component} key={component.displayName} {...exposedProps} />


    if @state.visible
      flexboxClassName += " registered-region-visible"
      elements.splice(0,0, <InjectedComponentLabel key="_label" matching={@props.matching} {...exposedProps} />)
      elements.push(<span key="_clear" style={clear:'both'}/>)

    <Flexbox className={flexboxClassName} {...flexboxProps}>
        {elements}
        {@props.children ? []}
    </Flexbox>

  _getStateFromStores: (props) =>
    props ?= @props

    components: ComponentRegistry.findComponentsMatching(@props.matching)
    visible: ComponentRegistry.showComponentRegions()


module.exports = InjectedComponentSet
