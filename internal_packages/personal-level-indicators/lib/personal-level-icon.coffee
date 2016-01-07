# # Personal Level Icon
#
# Show an icon for each thread to indicate whether you're the only recipient,
# one of many recipients, or a member of a mailing list.

# Access core components by requiring `nylas-exports`.
{Utils, DraftStore, React} = require 'nylas-exports'
# Access N1 React components by requiring `nylas-component-kit`.
{RetinaImg} = require 'nylas-component-kit'

class PersonalLevelIcon extends React.Component

  # Note: You should assign a new displayName to avoid naming
  # conflicts when injecting your item
  @displayName: 'PersonalLevelIcon'


  # In the constructor, we're setting the component's initial state.
  constructor: (@props) ->
    @state =
      level: @_calculateLevel(@props.thread)

  # React components' `render` methods return a virtual DOM element to render.
  # The returned DOM fragment is a result of the component's `state` and
  # `props`. In that sense, `render` methods are deterministic.
  render: =>
    React.createElement("div", {"className": "personal-level-icon"},
      (@_renderIcon())
    )

  # Some application logic which is specific to this package to decide which
  # character to render.
  _renderIcon: =>
    switch @state.level
      when 0 then ""
      when 1 then "\u3009"
      when 2 then "\u300b"
      when 3 then "\u21ba"

  # Some more application logic which is specific to this package to decide
  # what level of personalness is related to the `thread`.
  _calculateLevel: (thread) =>
    hasMe = (thread.participants.filter (p) -> p.isMe()).length > 0
    numOthers = thread.participants.length - hasMe
    if not hasMe
      return 0
    if numOthers > 1
      return 1
    if numOthers is 1
      return 2
    else
      return 3

module.exports = PersonalLevelIcon
