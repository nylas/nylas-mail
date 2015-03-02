React = require 'react'
{Utils} = require "inbox-exports"

module.exports =
RetinaImg = React.createClass
  displayName: 'RetinaImg'
  propTypes:
    name: React.PropTypes.string
    style: React.PropTypes.object
    className: React.PropTypes.string

    # Optional additional properties which adjust the provided
    # name. Makes it easy to write parent components when images
    # are used in some standard ways.
    fallback: React.PropTypes.string # Use when image cannot be found
    selected: React.PropTypes.bool # Appends -selected when true
    active: React.PropTypes.bool # Appends -active when true

  render: ->
    path = @_pathFor(@props.name) ? @_pathFor(@props.fallback) ? ''
    pathIsRetina = path.indexOf('@2x') > 0

    style = @props.style ? {}
    style.zoom = if pathIsRetina then 0.5 else 1

    <img className={@props.className ? ''} src={path} style={style} />
  
  _pathFor: (name) ->
    [basename, ext] = name.split('.')
    if @props.active is true
      name = "#{basename}-active.#{ext}"
    if @props.selected is true
      name = "#{basename}-selected.#{ext}"
    Utils.imageNamed(name)
