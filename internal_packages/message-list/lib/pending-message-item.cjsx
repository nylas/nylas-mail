React = require 'react'
{RetinaImg} = require 'nylas-component-kit'
MessageItem = require './message-item'

class PendingMessageItem extends MessageItem
  @displayName = 'PendingMessageItem'

  _renderMessageControls: -> null

  _renderHeaderDetailToggle: -> null

  _renderHeaderSideItems: ->
    styles =
      width: 24
      float: "left"
      marginTop: -2
      marginRight: 10

    <div style={styles}>
      <RetinaImg ref="spinner"
                 name="sending-spinner.gif"
                 mode={RetinaImg.Mode.ContentPreserve}/>
    </div>

module.exports = PendingMessageItem
