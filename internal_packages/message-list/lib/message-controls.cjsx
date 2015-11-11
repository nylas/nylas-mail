remote = require 'remote'
React = require 'react'
{Actions, NylasAPI, AccountStore} = require 'nylas-exports'
{RetinaImg, ButtonDropdown, Menu} = require 'nylas-component-kit'

class MessageControls extends React.Component
  @displayName: "MessageControls"
  @propTypes:
    thread: React.PropTypes.object.isRequired
    message: React.PropTypes.object.isRequired

  constructor: (@props) ->

  render: =>
    items = @_items()

    <div className="message-actions-wrap">
      <ButtonDropdown
        primaryItem={<RetinaImg name={items[0].image} mode={RetinaImg.Mode.ContentIsMask}/>}
        primaryTitle={items[0].name}
        primaryClick={items[0].select}
        menu={@_dropdownMenu(items[1..-1])}/>
      <div className="message-actions-ellipsis" onClick={@_onShowActionsMenu}>
        <RetinaImg name={"message-actions-ellipsis.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
    </div>

  _items: ->
    reply =
      name: 'Reply',
      image: 'ic-dropdown-reply.png'
      select: @_onReply
    replyAll =
      name: 'Reply All',
      image: 'ic-dropdown-replyall.png'
      select: @_onReplyAll
    forward =
      name: 'Forward',
      image: 'ic-dropdown-forward.png'
      select: @_onForward

    if @props.message.canReplyAll()
      defaultReplyType = NylasEnv.config.get('core.sending.defaultReplyType')
      if defaultReplyType is 'reply-all'
        return [replyAll, reply, forward]
      else
        return [reply, replyAll, forward]
    else
      return [reply, forward]

  _dropdownMenu: (items) ->
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
    myEmail = AccountStore.current()?.me().email.toLowerCase().trim()
    if @props.message.cc.length is 0 and @props.message.to.length is 1 and emails[0] is myEmail
      return "reply"
    else return "reply-all"

  _onShowActionsMenu: =>
    remote = require('remote')
    SystemMenu = remote.require('menu')
    SystemMenuItem = remote.require('menu-item')

    # Todo: refactor this so that message actions are provided
    # dynamically. Waiting to see if this will be used often.
    menu = new SystemMenu()
    menu.append(new SystemMenuItem({ label: 'Report Issue: Quoted Text', click: => @_onReport('Quoted Text')}))
    menu.append(new SystemMenuItem({ label: 'Report Issue: Rendering', click: => @_onReport('Rendering')}))
    menu.append(new SystemMenuItem({ type: 'separator'}))
    menu.append(new SystemMenuItem({ label: 'Show Original', click: => @_onShowOriginal()}))
    menu.append(new SystemMenuItem({ label: 'Log Data', click: => @_onLogData()}))
    menu.popup(remote.getCurrentWindow())

  _onReport: (issueType) =>
    {Contact, Message, DatabaseStore, AccountStore} = require 'nylas-exports'

    draft = new Message
      from: [AccountStore.current().me()]
      to: [new Contact(name: "Nylas Team", email: "feedback@nylas.com")]
      date: (new Date)
      draft: true
      subject: "Feedback - Message Display Issue (#{issueType})"
      accountId: AccountStore.current().id
      body: @props.message.body

    DatabaseStore.persistModel(draft).then =>
      Actions.sendDraft(draft.clientId)

      dialog = remote.require('dialog')
      dialog.showMessageBox remote.getCurrentWindow(), {
        type: 'warning'
        buttons: ['OK'],
        message: "Thank you."
        detail: "The contents of this message have been sent to the N1 team and we added to a test suite."
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
      path: "/messages/#{@props.message.id}"
      accountId: @props.message.accountId
      json:false
      success: (body) =>
        fs.writeFile tmpfile, body, =>
          window = new BrowserWindow(width: 800, height: 600, title: "#{@props.message.subject} - RFC822")
          window.loadUrl('file://'+tmpfile)

  _onLogData: =>
    console.log @props.message
    window.__message = @props.message
    window.__thread = @props.thread
    console.log "Also now available in window.__message and window.__thread"

module.exports = MessageControls
