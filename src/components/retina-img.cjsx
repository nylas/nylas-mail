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

###
Public: RetinaImg wraps the DOM's standard `<img`> tag and implements a `UIImage` style
  interface. Rather than specifying an image `src`, RetinaImg allows you to provide
  an image name. Like UIImage on iOS, it automatically finds the best image for the current
  display based on pixel density. Given `image.png`, on a Retina screen, it looks for 
  `image@2x.png`, `image.png`, `image@1x.png` in that order. It uses a lookup table and caches
  image names, so images generally resolve immediately.
###
class RetinaImg extends React.Component
  @displayName: 'RetinaImg'

  ###
  Public: React `props` supported by RetinaImg:
  
   - `name` (optional) A {String} image name to display.
   - `fallback` (optional) A {String} image name to use when `name` cannot be found.
   - `selected` (optional) Appends "-selected" to the end of the image name when when true
   - `active` (optional) Appends "-active" to the end of the image name when when true
   - `colorfill` (optional) Adds -webkit-mask-image and other styles, and the .colorfill CSS
      class, so that setting a CSS background color will colorfill the image.
   - `style` (optional) An {Object} with additional styles to apply to the image.
  ###
  @propTypes:
    name: React.PropTypes.string
    style: React.PropTypes.object
    fallback: React.PropTypes.string
    selected: React.PropTypes.bool
    active: React.PropTypes.bool
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


module.exports = RetinaImg