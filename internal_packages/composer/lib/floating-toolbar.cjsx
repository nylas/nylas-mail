_ = require 'underscore-plus'
React = require 'react'
{CompositeDisposable} = require 'event-kit'

module.exports =
FloatingToolbar = React.createClass
  getInitialState: ->
    mode: "buttons"
    urlInputValue: @_initialUrl() ? ""

  componentDidMount: ->
    @isHovering = false
    @subscriptions = new CompositeDisposable()
    @_saveUrl = _.debounce @__saveUrl, 10

  componentWillReceiveProps: (nextProps) ->
    @setState
      mode: nextProps.initialMode
      urlInputValue: @_initialUrl(nextProps)

  componentWillUnmount: ->
    @subscriptions?.dispose()
    @isHovering = false

  componentDidUpdate: ->
    if @state.mode is "edit-link" and not @props.linkToModify
      # Note, it's important that we're focused on the urlInput because
      # the parent of this component needs to know to not hide us on their
      # onBlur method.
      @refs.urlInput.getDOMNode().focus() if @isMounted()

  render: ->
    <div ref="floatingToolbar"
         className="floating-toolbar toolbar" style={@_toolbarStyles()}>
      <div className="toolbar-pointer" style={@_toolbarPointerStyles()}></div>
      {@_toolbarType()}
    </div>

  _toolbarType: ->
    if @state.mode is "buttons" then @_renderButtons()
    else if @state.mode is "edit-link" then @_renderLink()
    else return <div></div>

  _renderButtons: ->
    <div className="toolbar-buttons">
      <button className="btn btn-bold btn-icon"
              onClick={@_execCommand}
              data-command-name="bold"><strong>B</strong></button>
      <button className="btn btn-italic btn-icon"
              onClick={@_execCommand}
              data-command-name="italic"><em>I</em></button>
      <button className="btn btn-link btn-icon"
              onClick={@_showLink}
              data-command-name="link"><i className="fa fa-link"></i></button>
    </div>

  _renderLink: ->
    removeBtn = ""
    if @_initialUrl()
      removeBtn = <button className="btn btn-icon"
                          onMouseDown={@_removeUrl}><i className="fa fa-times"></i></button>

    <div className="toolbar-new-link"
         onMouseEnter={@_onMouseEnter}
         onMouseLeave={@_onMouseLeave}>
      <i className="fa fa-link preview-btn-icon"></i>
      <input type="text"
             ref="urlInput"
             value={@state.urlInputValue}
             onBlur={@_saveUrl}
             onKeyPress={@_saveUrlOnEnter}
             onChange={@_onInputChange}
             className="floating-toolbar-input"
             placeholder="Paste or type a link" />
      <button className="btn btn-icon"
              onKeyPress={@_saveUrlOnEnter}
              onMouseDown={@_saveUrl}><i className="fa fa-check"></i></button>
      {removeBtn}
    </div>

  _onMouseEnter: ->
    @isHovering = true
    @props.onMouseEnter?()

  _onMouseLeave: ->
    @isHovering = false
    if @props.linkToModify and document.activeElement isnt @refs.urlInput.getDOMNode()
      @props.onMouseLeave?()


  _initialUrl: (props=@props) ->
    props.linkToModify?.getAttribute?('href')

  _onInputChange: (event) ->
    @setState urlInputValue: event.target.value

  _saveUrlOnEnter: (event) ->
    if event.key is "Enter" and @state.urlInputValue.trim().length > 0
      @_saveUrl()

  # We signify the removal of a url with an empty string. This protects us
  # from the case where people delete the url text and hit save. In that
  # case we also want to remove the link.
  _removeUrl: ->
    @setState urlInputValue: ""
    @props.onSaveUrl "", @props.linkToModify

  __saveUrl: ->
    @props.onSaveUrl @state.urlInputValue, @props.linkToModify

  _execCommand: (event) ->
    cmd = event.currentTarget.getAttribute 'data-command-name'
    document.execCommand(cmd, false, null)
    true

  _toolbarStyles: ->
    styles =
      left: @_toolbarLeft()
      top: @props.top
      display: if @props.visible then "block" else "none"
    return styles

  _toolbarLeft: ->
    CONTENT_PADDING = @props.contentPadding ? 15
    max = @props.editAreaWidth - @_halfWidth()*2 - CONTENT_PADDING
    left = Math.min(Math.max(@props.left - @_halfWidth(), CONTENT_PADDING), max)
    return left

  _toolbarPointerStyles: ->
    CONTENT_PADDING = @props.contentPadding ? 15
    POINTER_WIDTH = 6 + 2 #2px of border-radius
    max = @props.editAreaWidth - CONTENT_PADDING
    min = CONTENT_PADDING
    absoluteLeft = Math.max(Math.min(@props.left, max), min)
    relativeLeft = absoluteLeft - @_toolbarLeft()

    left = Math.max(Math.min(relativeLeft, @_halfWidth()*2-POINTER_WIDTH), POINTER_WIDTH)
    styles =
      left: left
    return styles

  _halfWidth: ->
    # We can't calculate the width of the floating toolbar declaratively
    # because it hasn't been rendered yet. As such, we'll keep the width
    # fixed to make it much eaier.
    TOOLBAR_BUTTONS_WIDTH = 86#px
    TOOLBAR_URL_WIDTH = 210#px

    if @state.mode is "buttons"
      TOOLBAR_BUTTONS_WIDTH / 2
    else if @state.mode is "edit-link"
      TOOLBAR_URL_WIDTH / 2
    else
      TOOLBAR_BUTTONS_WIDTH / 2

  _showLink: ->
    @setState mode: "edit-link"
