React = require 'react'
AutoloadImagesStore = require './autoload-images-store'
Actions = require './autoload-images-actions'
{Message} = require 'nylas-exports'

class AutoloadImagesHeader extends React.Component
  @displayName: 'AutoloadImagesHeader'

  @propTypes:
    message: React.PropTypes.instanceOf(Message).isRequired

  constructor: (@props) ->

  render: =>
    if AutoloadImagesStore.shouldBlockImagesIn(@props.message)
      <div className="autoload-images-header">
        <a className="option" onClick={ => Actions.temporarilyEnableImages(@props.message) }>Show Images</a>
        <span style={paddingLeft: 10, paddingRight: 10}>|</span>
        <a className="option" onClick={ => Actions.permanentlyEnableImages(@props.message) }>Always show images from {@props.message.fromContact().toString()}</a>
      </div>
    else
      <div></div>

module.exports = AutoloadImagesHeader
