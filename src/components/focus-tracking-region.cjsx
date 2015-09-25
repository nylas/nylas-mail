React = require 'react'
_ = require 'underscore'

# Public: FocusTrackingRegion is a small wrap component that renders it's children
# and any props it's provided. Whenever the document's focus is inside the
# FocusTrackingRegion, it has an additional CSS class: `focused`
#
class FocusTrackingRegion extends React.Component
  @displayName: 'FocusTrackingRegion'

  @propTypes:
    className: React.PropTypes.string
    children: React.PropTypes.any

  constructor: (@props) ->
    @state = {focused: false}
    @_goingout = false

    @_in = =>
      @_goingout = false
      @setState(focused: true)

    @_out = =>
      @_goingout = true
      setTimeout =>
        return unless @_goingout

        # If we're unmounted the `@_goingout` flag will catch the unmount
        # @_goingout is set to true when we umount
        #
        # It's posible for a focusout event to fire from within a region
        # that we're actually focsued on.
        #
        # This happens when component that used to have the focus is
        # unmounted. An example is the url input field of the
        # FloatingToolbar in the Composer's Contenteditable
        el = React.findDOMNode(@)
        return if el.contains document.activeElement

        # This prevents the strange effect of an input appearing to have focus
        # when the element receiving focus does not support selection (like a
        # div with tabIndex=-1)
        document.getSelection().empty()
        @setState(focused: false)
        @_goingout = false
      , 100

  componentDidMount: ->
    el = React.findDOMNode(@)
    el.addEventListener('focusin', @_in)
    el.addEventListener('focusout', @_out)

  componentWillUnmount: ->
    el = React.findDOMNode(@)
    el.removeEventListener('focusin', @_in)
    el.removeEventListener('focusout', @_out)
    @_goingout = false

  render: ->
    className = @props.className
    className += " focused" if @state.focused
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    <div className={className} {...otherProps}>{@props.children}</div>

module.exports = FocusTrackingRegion
