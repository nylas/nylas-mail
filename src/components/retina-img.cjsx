_ = require 'underscore-plus'
React = require 'react'
{Utils} = require "inbox-exports"

StylesImpactedByZoom = [
  'top',
  'left',
  'right',
  'bottom',
  'paddingTop',
  'paddingLeft',
  'paddingRight',
  'paddingBottom',
  'marginTop',
  'marginBottom',
  'marginLeft',
  'marginRight'
]

module.exports =
RetinaImg = React.createClass
  displayName: 'RetinaImg'
  propTypes:
    name: React.PropTypes.string
    style: React.PropTypes.object

    # Optional additional properties which adjust the provided
    # name. Makes it easy to write parent components when images
    # are used in some standard ways.
    
    # Use when image cannot be found
    fallback: React.PropTypes.string
    
    # Appends -selected when true
    selected: React.PropTypes.bool
    
    # Appends -active when true
    active: React.PropTypes.bool

    # Adds -webkit-mask-image and other styles, and the .colorfill CSS
    # class, so that setting a CSS background color will colorfill the image.
    colorfill: React.PropTypes.bool

  render: ->
    path = @_pathFor(@props.name) ? @_pathFor(@props.fallback) ? ''
    pathIsRetina = path.indexOf('@2x') > 0
    className = undefined

    style = @props.style ? {}
    style.WebkitUserDrag = 'none'
    style.zoom = if pathIsRetina then 0.5 else 1

    if @props.colorfill
      style.WebkitMaskImage = "url(#{path})"
      style.objectPosition = "10000px"
      className = "colorfill"

    for key, val of style
      val = "#{val}"
      if key in StylesImpactedByZoom and val.indexOf('%') is -1
        style[key] = val.replace('px','') / style.zoom

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    <img className={className} src={path} style={style} {...otherProps} />
  
  _pathFor: (name) ->
    [basename, ext] = name.split('.')
    if @props.active is true
      name = "#{basename}-active.#{ext}"
    if @props.selected is true
      name = "#{basename}-selected.#{ext}"
    Utils.imageNamed(name)
