React = require 'react'
{remote} = require 'electron'
{Actions, NylasAPI, NylasAPIRequest, AccountStore} = require 'nylas-exports'
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
        closeOnMenuClick={true}
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

  _account: =>
    AccountStore.accountForId(@props.message.accountId)

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
    {thread, message} = @props
    Actions.composeReply({thread, message, type: 'reply', behavior: 'prefer-existing-if-pristine'})

  _onReplyAll: =>
    {thread, message} = @props
    Actions.composeReply({thread, message, type: 'reply-all', behavior: 'prefer-existing-if-pristine'})

  _onForward: =>
    {thread, message} = @props
    Actions.composeForward({thread, message})

  _onShowActionsMenu: =>
    SystemMenu = remote.Menu
    SystemMenuItem = remote.MenuItem

    # Todo: refactor this so that message actions are provided
    # dynamically. Waiting to see if this will be used often.
    menu = new SystemMenu()
    menu.append(new SystemMenuItem({ label: 'Log Data', click: => @_onLogData()}))
    menu.append(new SystemMenuItem({ label: 'Show Original', click: => @_onShowOriginal()}))
    menu.append(new SystemMenuItem({ label: 'Copy Debug Info to Clipboard', click: => @_onCopyToClipboard()}))
    menu.popup(remote.getCurrentWindow())

  _onShowOriginal: =>
    fs = require 'fs'
    path = require 'path'
    BrowserWindow = remote.BrowserWindow
    app = remote.app
    tmpfile = path.join(app.getPath('temp'), @props.message.id)

    request = new NylasAPIRequest
      api: NylasAPI
      options:
        headers:
          Accept: 'message/rfc822'
        path: "/messages/#{@props.message.id}"
        accountId: @props.message.accountId
        json:false
    request.run()
    .then((body) =>
      fs.writeFile tmpfile, body, =>
        window = new BrowserWindow(width: 800, height: 600, title: "#{@props.message.subject} - RFC822")
        window.loadURL('file://'+tmpfile)
    )

  _onLogData: =>
    console.log @props.message
    window.__message = @props.message
    window.__thread = @props.thread
    console.log "Also now available in window.__message and window.__thread"

  _onCopyToClipboard: =>
    clipboard = require('electron').clipboard
    data = "AccountID: #{@props.message.accountId}\n"+
      "Message ID: #{@props.message.serverId}\n"+
      "Message Metadata: #{JSON.stringify(@props.message.pluginMetadata, null, '  ')}\n"+
      "Thread ID: #{@props.thread.serverId}\n"+
      "Thread Metadata: #{JSON.stringify(@props.thread.pluginMetadata, null, '  ')}\n"

    clipboard.writeText(data)

module.exports = MessageControls
