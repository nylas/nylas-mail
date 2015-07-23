React = require 'react'
RetinaImg = require './retina-img'
CategoryStore = require '../flux/stores/category-store'

LabelColorizer =

  color: (label) -> "hsl(#{label.hue()}, 50%, 34%)"

  backgroundColor: (label) -> "hsl(#{label.hue()}, 62%, 87%)"
  backgroundColorDark: (label) -> "hsl(#{label.hue()}, 62%, 57%)"

  styles: (label) ->
    color: LabelColorizer.color(label)
    backgroundColor: LabelColorizer.backgroundColor(label)
    boxShadow: "inset 0 0 1px hsl(#{label.hue()}, 62%, 47%), inset 0 1px 1px rgba(255,255,255,0.5), 0 0.5px 0 rgba(255,255,255,0.5)"
    backgroundImage: 'linear-gradient(rgba(255,255,255, 0.4), rgba(255,255,255,0))'

class MailLabel extends React.Component
  @propTypes:
    label: React.PropTypes.object.isRequired
    onRemove: React.PropTypes.function

  shouldComponentUpdate: (nextProps, nextState) ->
    return false if nextProps.label.id is @props.label.id
    true

  render: ->
    classname = 'mail-label'
    content = @props.label.displayName

    x = null
    if @_removable()
      classname += ' removable'
      content = <span className="inner">{content}</span>
      x = <RetinaImg
        className="x"
        name="label-x.png"
        style={backgroundColor: LabelColorizer.color(@props.label)}
        mode={RetinaImg.Mode.ContentIsMask}
        onClick={@props.onRemove}/>

    <div className={classname} style={LabelColorizer.styles(@props.label)}>{content}{x}</div>

  _removable: ->
    isLockedLabel = @props.label.name in CategoryStore.LockedCategoryNames
    return @props.onRemove and not isLockedLabel

module.exports = {MailLabel, LabelColorizer}
