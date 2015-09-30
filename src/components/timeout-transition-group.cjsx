# WHY IS THIS FILE HERE? ReactCSSTransitionGroup is causing
# inconsitency exceptions when you hammer on the animations and don't let them
# finish. This is from http://khan.github.io/react-components/#timeout-transition-group
# and uses timeouts to clean up elements rather than listeners on CSS events, which
# don't always seem to fire.

# https://github.com/facebook/react/issues/1707

React = require('react/addons')
PriorityUICoordinator = require('../priority-ui-coordinator')
ReactTransitionGroup = React.addons.TransitionGroup
TICK = 17

endEvents = ['webkitTransitionEnd', 'webkitAnimationEnd']

animationSupported = => true

###*
# Functions for element class management to replace dependency on jQuery
# addClass, removeClass and hasClass
###

addClass = (element, className) =>
  element.classList.add(className)
  element

removeClass = (element, className) =>
  if element.classList.contains(className)
    element.classList.remove(className)
  element


###
Public: TimeoutTransitionGroup applies a CSS transition to the components added
or removed from it's children. It is similar to React's CSSTransitionGroup, but
that uses the 'transitionend' event, which browsers will not send for any
number of reasons, including the transitioning node not being painted.

This TimeoutTransitionGroup instead uses a user-defined timeout to determine
when it is a good time to remove the component. Currently there is only one
timeout specified, but in the future it would be nice to be able to specify
separate timeouts for enter and leave, in case the timeouts for those
animations differ. Even nicer would be some sort of inspection of the CSS to
automatically determine the duration of the animation or transition.

This is adapted from Facebook's CSSTransitionGroup which is in the React
addons and under the Apache 2.0 License.

Example:
```coffee
<TimeoutTransitionGroup
  leaveTimeout={125}
  enterTimeout={125}
  transitionName="sheet-toolbar">
  {toolbarElements[1..-1]}
</TimeoutTransitionGroup>
```

Section: Component Kit
###
class TimeoutTransitionGroupChild extends React.Component

  transition: (animationType, finishCallback) =>
    node = React.findDOMNode(@)
    return unless node
    className = @props.name + '-' + animationType
    activeClassName = className + '-active'

    # If you animate back and forth fast enough, you can call `transition`
    # before a previous transition has finished. Make sure we cancel the
    # old timeout.
    if @animationTimeout
      clearTimeout(@animationTimeout)
      @animationTimeout = null

    if @animationTaskId
      PriorityUICoordinator.endPriorityTask(@animationTaskId)
      @animationTaskId = null

    # Block database responses, JSON parsing while we are in flight
    @animationTaskId = PriorityUICoordinator.beginPriorityTask()

    endListener = =>
      removeClass(node, className)
      removeClass(node, activeClassName)
      # Usually this optional callback is used for informing an owner of
      # a leave animation and telling it to remove the child.
      finishCallback and finishCallback()

      if @animationTaskId
        PriorityUICoordinator.endPriorityTask(@animationTaskId)
        @animationTaskId = null
      @animationTimeout = null
      return

    if !animationSupported()
      endListener()
    else
      if animationType == 'enter'
        @animationTimeout = setTimeout(endListener, @props.enterTimeout)
      else if animationType == 'leave'
        @animationTimeout = setTimeout(endListener, @props.leaveTimeout)

    addClass(node, className)

    # Need to do this to actually trigger a transition.
    @queueClass activeClassName
    return

  queueClass: (className) =>
    @classNameQueue.push className
    if !@timeout
      @timeout = setTimeout(@flushClassNameQueue, TICK)
    return

  flushClassNameQueue: =>
    @classNameQueue.forEach ((name) =>
      addClass(React.findDOMNode(@), name)
      return
    ).bind(this)
    @classNameQueue.length = 0
    @timeout = null
    return

  componentWillMount: =>
    @classNameQueue = []
    @animationTimeout = null
    @animationTaskId = null
    return

  componentWillUnmount: =>
    if @timeout
      clearTimeout(@timeout)
    if @animationTimeout
      clearTimeout(@animationTimeout)
      @animationTimeout = null
    if @animationTaskId
      PriorityUICoordinator.endPriorityTask(@animationTaskId)
      @animationTaskId = null
    return

  componentWillEnter: (done) =>
    if @props.enter
      @transition 'enter', done
    else
      done()
    return

  componentWillLeave: (done) =>
    if @props.leave
      @transition 'leave', done
    else
      done()
    return

  render: =>
    React.Children.only @props.children

class TimeoutTransitionGroup extends React.Component
  @propTypes =
    enterTimeout: React.PropTypes.number.isRequired
    leaveTimeout: React.PropTypes.number.isRequired
    transitionName: React.PropTypes.string.isRequired
    transitionEnter: React.PropTypes.bool
    transitionLeave: React.PropTypes.bool

  @defaultProps =
    transitionEnter: true
    transitionLeave: true

  _wrapChild: (child) =>
    <TimeoutTransitionGroupChild
      enterTimeout={@props.enterTimeout}
      leaveTimeout={@props.leaveTimeout}
      name={@props.transitionName}
      enter={@props.transitionEnter}
      leave={@props.transitionLeave}>
        {child}
    </TimeoutTransitionGroupChild>

  render: =>
    <ReactTransitionGroup
        {...@props}
        childFactory={@_wrapChild} />


module.exports = TimeoutTransitionGroup
