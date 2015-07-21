remote = require 'remote'
React = require 'react'
{Actions, NylasAPI, NamespaceStore} = require 'nylas-exports'
{RetinaImg, ButtonDropdown, Menu} = require 'nylas-component-kit'

class MessageControls extends React.Component
  @displayName: "MessageControls"
  @propTypes:
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired

  constructor: (@props) ->

  render: =>
    <div className="message-actions-wrap">
      <div className="message-actions-ellipsis" onClick={@_onShowActionsMenu}>
        <RetinaImg name={"message-actions-ellipsis.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
      <ButtonDropdown
        primaryItem={<RetinaImg name="ic-message-button-reply.png" mode={RetinaImg.Mode.ContentIsMask}/>}
        primaryClick={@_onReply}
        menu={@_dropdownMenu()}/>
    </div>

  _dropdownMenu: ->
    items = [{
      name: 'Reply All',
      image: 'ic-dropdown-replyall.png'
      select: @_onReplyAll
    },{
      name: 'Forward',
      image: 'ic-dropdown-forward.png'
      select: @_onForward
    }]

    itemContent = (item) ->
      <span>
        <RetinaImg name={item.image} mode={RetinaImg.Mode.ContentIsMask}/>
        &nbsp;&nbsp;{item.name}
      </span>

    <Menu items={items}
          itemKey={ (item) -> item.name }
          itemContent={itemContent}
          onSelect={ (item) => item.select() }
          />

  _onReply: =>
    Actions.composeReply(thread: @props.thread, message: @props.message)

  _onReplyAll: =>
    Actions.composeReplyAll(thread: @props.thread, message: @props.message)

  _onForward: =>
    Actions.composeForward(thread: @props.thread, message: @props.message)

  _replyType: =>
    emails = @props.message.to.map (item) -> item.email.toLowerCase().trim()
    myEmail = NamespaceStore.current()?.me().email.toLowerCase().trim()
    if @props.message.cc.length is 0 and @props.message.to.length is 1 and emails[0] is myEmail
      return "reply"
    else return "reply-all"

  _onShowActionsMenu: =>
    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    # Todo: refactor this so that message actions are provided
    # dynamically. Waiting to see if this will be used often.
    menu = new Menu()
    menu.append(new MenuItem({ label: 'Report Issue: Quoted Text', click: => @_onReport('Quoted Text')}))
    menu.append(new MenuItem({ label: 'Report Issue: Rendering', click: => @_onReport('Rendering')}))
    menu.append(new MenuItem({ type: 'separator'}))
    menu.append(new MenuItem({ label: 'Show Original', click: => @_onShowOriginal()}))
    menu.popup(remote.getCurrentWindow())

  _onReport: (issueType) =>
    {Contact, Message, DatabaseStore, NamespaceStore} = require 'nylas-exports'

    draft = new Message
      from: [NamespaceStore.current().me()]
      to: [new Contact(name: "Nylas Team", email: "feedback@nylas.com")]
      date: (new Date)
      draft: true
      subject: "Feedback - Message Display Issue (#{issueType})"
      namespaceId: NamespaceStore.current().id
      body: @props.message.body

    DatabaseStore.persistModel(draft).then =>
      DatabaseStore.localIdForModel(draft).then (localId) =>
        Actions.sendDraft(localId)

        dialog = remote.require('dialog')
        dialog.showMessageBox remote.getCurrentWindow(), {
          type: 'warning'
          buttons: ['OK'],
          message: "Thank you."
          detail: "The contents of this message have been sent to the Edgehill team and we added to a test suite."
        }

  _onShowOriginal: =>
    fs = require 'fs'
    path = require 'path'
    BrowserWindow = remote.require('browser-window')
    app = remote.require('app')
    tmpfile = path.join(app.getPath('temp'), @props.message.id)

    NylasAPI.makeRequest
      headers:
        Accept: 'message/rfc822'
      path: "/n/#{@props.message.namespaceId}/messages/#{@props.message.id}"
      json:false
      success: (body) =>
        fs.writeFile tmpfile, body, =>
          window = new BrowserWindow(width: 800, height: 600, title: "#{@props.message.subject} - RFC822")
          window.loadUrl('file://'+tmpfile)


module.exports = MessageControls
