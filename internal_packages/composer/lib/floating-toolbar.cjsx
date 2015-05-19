_ = require 'underscore'
React = require 'react/addons'
classNames = require 'classnames'
{CompositeDisposable} = require 'event-kit'
{RetinaImg} = require 'nylas-component-kit'

class FloatingToolbar extends React.Component
  @displayName = "FloatingToolbar"

  constructor: (@props) ->
    @state =
      mode: "buttons"
      urlInputValue: @_initialUrl() ? ""

  componentDidMount: =>
    @isHovering = false
    @subscriptions = new CompositeDisposable()
    @_saveUrl = _.debounce @__saveUrl, 10

  componentWillReceiveProps: (nextProps) =>
    @setState
      mode: nextProps.initialMode
      urlInputValue: @_initialUrl(nextProps)

  componentWillUnmount: =>
    @subscriptions?.dispose()
    @isHovering = false

  componentDidUpdate: =>
    if @state.mode is "edit-link" and not @props.linkToModify
      # Note, it's important that we're focused on the urlInput because
      # the parent of this component needs to know to not hide us on their
      # onBlur method.
      React.findDOMNode(@refs.urlInput).focus()

  render: =>
    <div ref="floatingToolbar"
         className={@_toolbarClasses()} style={@_toolbarStyles()}>
      <div className="toolbar-pointer" style={@_toolbarPointerStyles()}></div>
      {@_toolbarType()}
    </div>

  _toolbarClasses: =>
    classes = {}
    classes[@props.pos] = true
    classNames _.extend classes,
      "floating-toolbar": true
      "toolbar": true
      "toolbar-visible": @props.visible

  _toolbarStyles: =>
    styles =
      left: @_toolbarLeft()
      top: @props.top
      width: @_width()
    return styles

  _toolbarType: =>
    if @state.mode is "buttons" then @_renderButtons()
    else if @state.mode is "edit-link" then @_renderLink()
    else return <div></div>

  _renderButtons: =>
    <div className="toolbar-buttons">
      <button className="btn btn-bold toolbar-btn"
              onClick={@_execCommand}
              data-command-name="bold"></button>
      <button className="btn btn-italic toolbar-btn"
              onClick={@_execCommand}
              data-command-name="italic"></button>
      <button className="btn btn-underline toolbar-btn"
              onClick={@_execCommand}
              data-command-name="underline"></button>
      <button className="btn btn-link toolbar-btn"
              onClick={@_showLink}
              data-command-name="link"></button>
    </div>

  _renderLink: =>
    removeBtn = ""
    withRemove = ""
    if @_initialUrl()
      withRemove = "with-remove"
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
             className="floating-toolbar-input #{withRemove}"
             placeholder="Paste or type a link" />
      <button className="btn btn-icon"
              onKeyPress={@_saveUrlOnEnter}
              onMouseDown={@_saveUrl}><i className="fa fa-check"></i></button>
      {removeBtn}
    </div>

  _onMouseEnter: =>
    @isHovering = true
    @props.onMouseEnter?()

  _onMouseLeave: =>
    @isHovering = false
    if @props.linkToModify and document.activeElement isnt React.findDOMNode(@refs.urlInput)
      @props.onMouseLeave?()


  _initialUrl: (props=@props) =>
    props.linkToModify?.getAttribute?('href')

  _onInputChange: (event) =>
    @setState urlInputValue: event.target.value

  _saveUrlOnEnter: (event) =>
    if event.key is "Enter" and @state.urlInputValue.trim().length > 0
      @_saveUrl()

  # We signify the removal of a url with an empty string. This protects us
  # from the case where people delete the url text and hit save. In that
  # case we also want to remove the link.
  _removeUrl: =>
    @setState urlInputValue: ""
    @props.onSaveUrl "", @props.linkToModify

  __saveUrl: =>
    return unless @state.urlInputValue?
    @props.onSaveUrl @state.urlInputValue, @props.linkToModify

  _execCommand: (event) =>
    cmd = event.currentTarget.getAttribute 'data-command-name'
    document.execCommand(cmd, false, null)
    true

  _toolbarLeft: =>
    CONTENT_PADDING = @props.contentPadding ? 15
    max = @props.editAreaWidth - @_width() - CONTENT_PADDING
    left = Math.min(Math.max(@props.left - @_width()/2, CONTENT_PADDING), max)
    return left

  _toolbarPointerStyles: =>
    CONTENT_PADDING = @props.contentPadding ? 15
    POINTER_WIDTH = 6 + 2 #2px of border-radius
    max = @props.editAreaWidth - CONTENT_PADDING
    min = CONTENT_PADDING
    absoluteLeft = Math.max(Math.min(@props.left, max), min)
    relativeLeft = absoluteLeft - @_toolbarLeft()

    left = Math.max(Math.min(relativeLeft, @_width()-POINTER_WIDTH), POINTER_WIDTH)
    styles =
      left: left
    return styles

  _width: =>
    # We can't calculate the width of the floating toolbar declaratively
    # because it hasn't been rendered yet. As such, we'll keep the width
    # fixed to make it much eaier.
    TOOLBAR_BUTTONS_WIDTH = 114#px
    TOOLBAR_URL_WIDTH = 210#px

    # If we have a long link, we want to make a larger text area. It's not
    # super important to get the length exactly so let's just get within
    # the ballpark by guessing charcter lengths
    WIDTH_PER_CHAR = 11
    max = @props.editAreaWidth - (@props.contentPadding ? 15)*2

    if @state.mode is "buttons"
      return TOOLBAR_BUTTONS_WIDTH
    else if @state.mode is "edit-link"
      url = @_initialUrl()
      if url?.length > 0
        fullWidth = Math.max(Math.min(url.length * WIDTH_PER_CHAR, max), TOOLBAR_URL_WIDTH)
        return fullWidth
      else
        return TOOLBAR_URL_WIDTH
    else
      return TOOLBAR_BUTTONS_WIDTH

  _showLink: =>
    @setState mode: "edit-link"

module.exports = FloatingToolbar
