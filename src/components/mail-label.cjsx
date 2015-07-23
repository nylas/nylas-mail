React = require 'react'
RetinaImg = require './retina-img'
CategoryStore = require '../flux/stores/category-store'

class MailLabel extends React.Component
  @propTypes:
    label: React.PropTypes.object.isRequired
    onRemove: React.PropTypes.function

  render: ->
    hue = @props.label.hue()
    style =
      backgroundColor: "hsl(#{hue}, 62%, 87%)"
      color: "hsl(#{hue}, 50%, 34%)"
      boxShadow: "inset 0 0 1px hsl(#{hue}, 62%, 47%), inset 0 1px 1px rgba(255,255,255,0.5), 0 0.5px 0 rgba(255,255,255,0.5)"
      backgroundImage: 'linear-gradient(rgba(255,255,255, 0.4), rgba(255,255,255,0))'

    classname = 'mail-label'
    content = @props.label.displayName

    x = null
    if @_removable()
      classname += ' removable'
      content = <span className="inner">{content}</span>
      x = <RetinaImg
        className="x"
        name="label-x.png"
        style={backgroundColor: "hsl(#{hue}, 50%, 34%)"}
        mode={RetinaImg.Mode.ContentIsMask}
        onClick={@props.onRemove}/>

    <div className={classname} style={style}>{content}{x}</div>

  _removable: ->
    isLockedLabel = @props.label.name in CategoryStore.LockedCategoryNames
    return @props.onRemove and not isLockedLabel

module.exports = MailLabel
