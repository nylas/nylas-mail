React = require 'react'
_ = require 'underscore-plus'

###
Public: Renders a component provided via the `component` prop, and ensures that
failures in the component's code do not cause state inconsistencies elsewhere in
the application. This component is used by {InjectedComponent} and
{InjectedComponentSet} to isolate third party code that could be buggy.

Occasionally, having your component wrapped in {UnsafeComponent} can cause style
issues. For example, in a Flexbox, the `div.unsafe-component-wrapper` will cause
your `flex` and `order` values to be one level too deep. For these scenarios,
UnsafeComponent looks for `containerStyles` on your React component and attaches
them to the wrapper div:

```
class MyComponent extends React.Component
  @displayName: 'MyComponent'
  @containerStyles:
    flex: 1
    order: 2
```

###
class UnsafeComponent extends React.Component
  @displayName: 'UnsafeComponent'

  ###
  Public: React `props` supported by UnsafeComponent:

   - `component` The {React.Component} to display. All other props will be
     passed on to this component.
  ###
  @propTypes:
    component: React.PropTypes.func.isRequired

  componentDidMount: =>
    @renderInjected()

  componentDidUpdate: =>
    @renderInjected()

  componentWillUnmount: =>
    @unmountInjected()

  render: =>
    <div name="unsafe-component-wrapper" style={@props.component?.containerStyles}></div>

  renderInjected: =>
    node = React.findDOMNode(@)
    element = null
    try
      props = _.omit(@props, _.keys(@constructor.propTypes))
      component = @props.component
      element = <component key={name} {...props} />
      @injected = React.render(element, node)
    catch err
      stack = err.stack
      stackEnd = stack.indexOf('react/lib/')
      if stackEnd > 0
        stackEnd = stack.lastIndexOf('\n', stackEnd)
        stack = stack.substr(0,stackEnd)

      element = <div className="unsafe-component-exception">
        <div className="message">{@props.component.displayName} could not be displayed.</div>
        <div className="trace">{stack}</div>
      </div>

    @injected = React.render(element, node)

  unmountInjected: =>
    try
      node = React.findDOMNode(@)
      React.unmountComponentAtNode(node)
    catch err

  focus: =>
    # Not forwarding event - just a method call
    @injected.focus() if @injected.focus?

  blur: =>
    # Not forwarding an event - just a method call
    @injected.blur() if @injected.blur?


module.exports = UnsafeComponent
