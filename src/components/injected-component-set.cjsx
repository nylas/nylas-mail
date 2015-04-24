React = require 'react'
_ = require 'underscore-plus'
{Actions,
 WorkspaceStore,
 ComponentRegistry} = require "inbox-exports"

###
Public: InjectedComponent makes it easy to include a set of dynamically registered
components inside of your React render method. Rather than explicitly render
an array of buttons, for example, you can use InjectedComponentSet:

```
<InjectedComponentSet className="message-actions"
                  location="MessageAction"
                  thread={@props.thread}
                  message={@props.message}>
```

InjectedComponentSet will look up components registered for the location you provide,
render them inside a `<span>` and pass any additional props, like `thread` and `message`
along.

InjectedComponentSet monitors the ComponentRegistry for changes. If a new component
is registered into the location you provide, InjectedComponentSet will re-render.

If no matching components is found, the InjectedComponent renders an empty span.
###
class InjectedComponentSet extends React.Component
  @displayName: 'InjectedComponentSet'

  ###
  Public: React `props` supported by InjectedComponentSet:
  
   - `location` (optional) Pass a {String} location. Components are looked up
      using this location key.
   - `style` (optional) An {Object} with additional styles to apply to the containing element.
   - `className` (optional) A {String} class name for the containing element.
   - `children` (optional) Any React elements rendered inside the InjectedComponentSet
     will always be displayed.
  ###
  @propTypes:
    location: React.PropTypes.string.isRequired
    style: React.PropTypes.object
    className: React.PropTypes.string
    children: React.PropTypes.array

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

  _getStateFromStores: (props) =>
    props ?= @props

    components: ComponentRegistry.findAllByRole(@props.location)
    visible: ComponentRegistry.showComponentRegions()


module.exports = InjectedComponentSet