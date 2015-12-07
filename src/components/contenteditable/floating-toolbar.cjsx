_ = require 'underscore'
React = require 'react/addons'
classNames = require 'classnames'
{CompositeDisposable} = require 'event-kit'
{RetinaImg} = require 'nylas-component-kit'
{ExtensionRegistry} = require 'nylas-exports'

class FloatingToolbar extends React.Component
  @displayName = "FloatingToolbar"

  @propTypes:
    # Absolute position in px relative to parent <Contenteditable />
    top: React.PropTypes.number

    # Absolute position in px relative to parent <Contenteditable />
    left: React.PropTypes.number

    # Either "above" or "below". Used when determining which CSS to use
    pos: React.PropTypes.string

    # Either "edit-link" or "buttons". Determines whether we're showing
    # edit buttons or the link editor
    mode: React.PropTypes.string

    # The current display state of the toolbar
    visible: React.PropTypes.bool

    # A callback function we use to save the URL to the Contenteditable
    #
    # TODO: This only gets passed down because the Selection state must be
    # manually maniuplated to apply the link to the appropriate text via
    # the document.execcommand("createLink") command. This should get
    # refactored with the Selection state.
    onSaveUrl: React.PropTypes.func

    # A callback so our parent can decide whether or not to hide when the
    # mouse has moved over the component
    onMouseEnter: React.PropTypes.func
    onMouseLeave: React.PropTypes.func

    # The current DOM link we are modifying
    linkToModify: React.PropTypes.object

    # Declares what buttons should appear in the toolbar. An array of
    # config objects.
    buttonConfigs: React.PropTypes.array

    # Notifies our parent of when we focus in and out of inputs in the
    # toolbar.
    onChangeFocus: React.PropTypes.func

    # The absolute available area we have used in calculating our
    # appropriate position.
    editAreaWidth: React.PropTypes.number

    # The absolute available padding we have used in calculating our
    # appropriate position.
    contentPadding: React.PropTypes.number

    # A callback used when a link has been cancled, completed, or escaped
    # from. Used to notify our parent to switch modes.
    onDoneWithLink: React.PropTypes.func

  @defaultProps:
    mode: "buttons"
    onMouseEnter: ->
    onMouseLeave: ->
    buttonConfigs: []

  constructor: (@props) ->
    @state =
      urlInputValue: @_initialUrl() ? ""
      componentWidth: 0

  componentDidMount: =>
    @subscriptions = new CompositeDisposable()

  componentWillReceiveProps: (nextProps) =>
    @setState
      urlInputValue: @_initialUrl(nextProps)

  componentWillUnmount: =>
    @subscriptions?.dispose()

  componentDidUpdate: =>
    if @props.mode is "edit-link" and not @props.linkToModify
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
    if @props.mode is "buttons" then @_renderButtons()
    else if @props.mode is "edit-link" then @_renderLink()
    else return <div></div>

  _renderButtons: =>
    @props.buttonConfigs.map (config, i) ->
      if (config.iconUrl ? "").length > 0
        icon = <RetinaImg mode={RetinaImg.Mode.ContentIsMask}
                          url="#{toolbarItem.iconUrl}" />
      else icon = ""

      <button className="btn toolbar-btn #{config.className ? ''}"
              key={"btn-#{i}"}
              onClick={config.onClick}
              title="#{config.tooltip}">{icon}</button>

  _renderLink: =>
    removeBtn = ""
    withRemove = ""
    if @_initialUrl()
      withRemove = "with-remove"
      removeBtn = <button className="btn btn-icon"
                          ref="removeBtn"
                          onMouseDown={@_removeUrl}><i className="fa fa-times"></i></button>

    <div className="toolbar-new-link"
         onMouseEnter={@_onMouseEnter}
         onMouseLeave={@_onMouseLeave}>
      <i className="fa fa-link preview-btn-icon" onClick={@_onPreventToolbarClose}></i>
      <input type="text"
             ref="urlInput"
             value={@state.urlInputValue}
             onBlur={@_onBlur}
             onFocus={@_onFocus}
             onClick={@_onPreventToolbarClose}
             onKeyPress={@_saveUrlOnEnter}
             onChange={@_onInputChange}
             className="floating-toolbar-input #{withRemove}"
             placeholder="Paste or type a link" />
      <button className="btn btn-icon"
              ref="saveBtn"
              onKeyPress={@_saveUrlOnEnter}
              onMouseDown={@_saveUrl}><i className="fa fa-check"></i></button>
      {removeBtn}
    </div>

  _onPreventToolbarClose: (event) =>
    event.stopPropagation()

  _onMouseEnter: =>
    @props.onMouseEnter?()

  _onMouseLeave: =>
    if @props.linkToModify and document.activeElement isnt React.findDOMNode(@refs.urlInput)
      @props.onMouseLeave?()

  _initialUrl: (props=@props) =>
    props.linkToModify?.getAttribute?('href')

  _onInputChange: (event) =>
    @setState urlInputValue: event.target.value

  _saveUrlOnEnter: (event) =>
    if event.key is "Enter"
      if (@state.urlInputValue ? "").trim().length > 0
        @_saveUrl()
      else
        @_removeUrl()

  # We signify the removal of a url with an empty string. This protects us
  # from the case where people delete the url text and hit save. In that
  # case we also want to remove the link.
  _removeUrl: =>
    @setState urlInputValue: ""
    @props.onSaveUrl "", @props.linkToModify
    @props.onDoneWithLink()

  _onFocus: =>
    @props.onChangeFocus(true)

  # Clicking the save or remove buttons will take precendent over simply
  # bluring the field.
  _onBlur: (event) =>
    targets = []
    if @refs["saveBtn"]
      targets.push React.findDOMNode(@refs["saveBtn"])
    if @refs["removeBtn"]
      targets.push React.findDOMNode(@refs["removeBtn"])

    if event.relatedTarget in targets
      event.preventDefault()
      return
    else
      @_saveUrl()
      @props.onChangeFocus(false)

  _saveUrl: =>
    if (@state.urlInputValue ? "").trim().length > 0
      @props.onSaveUrl @state.urlInputValue, @props.linkToModify
    @props.onDoneWithLink()

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

    if @props.mode is "buttons"
      return TOOLBAR_BUTTONS_WIDTH
    else if @props.mode is "edit-link"
      url = @_initialUrl()
      if url?.length > 0
        fullWidth = Math.max(Math.min(url.length * WIDTH_PER_CHAR, max), TOOLBAR_URL_WIDTH)
        return fullWidth
      else
        return TOOLBAR_URL_WIDTH
    else
      return TOOLBAR_BUTTONS_WIDTH

module.exports = FloatingToolbar
