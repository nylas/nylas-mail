React = require 'react'
ReactDOM = require 'react-dom'
classNames = require 'classnames'
_ = require 'underscore'
{CompositeDisposable} = require 'event-kit'
{Utils,
 Contact,
 RegExpUtils} = require 'nylas-exports'
RetinaImg = require('./retina-img').default

class SizeToFitInput extends React.Component
  constructor: (@props) ->
    @state = {}

  componentDidMount: =>
    @_sizeToFit()

  componentDidUpdate: =>
    @_sizeToFit()

  _sizeToFit: =>
    return if @props.value.length is 0
    # Measure the width of the text in the input and
    # resize the input field to fit.
    input = ReactDOM.findDOMNode(@refs.input)
    measure = ReactDOM.findDOMNode(@refs.measure)
    measure.innerText = input.value
    measure.style.top = input.offsetTop + "px"
    measure.style.left = input.offsetLeft + "px"
    # The 10px comes from the 7.5px left padding and 2.5px more of
    # breathing room.
    input.style.width = "#{measure.offsetWidth+10}px"

  render: =>
    <span>
      <span ref="measure" style={visibility:'hidden', position: 'absolute'}></span>
      <input ref="input" type="text" style={width: 1} {...@props}/>
    </span>

  select: =>
    ReactDOM.findDOMNode(@refs.input).select()

  focus: =>
    ReactDOM.findDOMNode(@refs.input).focus()

class Token extends React.Component
  @displayName: "Token"

  @propTypes:
    className: React.PropTypes.string,
    selected: React.PropTypes.bool,
    valid: React.PropTypes.bool,
    item: React.PropTypes.object,
    onSelected: React.PropTypes.func.isRequired,
    onEdited: React.PropTypes.func,
    onAction: React.PropTypes.func

  @defaultProps:
    className: ''

  constructor: (@props) ->
    @state =
      editing: false
      editingValue: @props.item.toString()

  render: =>
    if @state.editing
      @_renderEditing()
    else
      @_renderViewing()

  componentDidUpdate: (prevProps, prevState) =>
    if @state.editing && !prevState.editing
      @refs.input.select()

  componentWillReceiveProps: (props) =>
    # never override the text the user is editing if they're looking at it
    return if @state.editing
    @setState(editingValue: @props.item.toString())

  _renderEditing: =>
    <SizeToFitInput
      ref="input"
      className="token-editing-input"
      spellCheck="false"
      value={@state.editingValue}
      onKeyDown={@_onEditKeydown}
      onBlur={@_onEditFinished}
      onChange={ (event) => @setState(editingValue: event.target.value)}/>

  _renderViewing: =>
    classes = classNames
      "token": true
      "dragging": @state.dragging
      "invalid": !@props.valid
      "selected": @props.selected

    <div className={"#{classes} #{@props.className}"}
         onDragStart={@_onDragStart}
         onDragEnd={@_onDragEnd}
         draggable="true"
         onDoubleClick={@_onDoubleClick}
         onClick={@_onSelect}>
      {if @props.onAction
        <button className="action" onClick={@_onAction} tabIndex={-1}>
          <RetinaImg mode={RetinaImg.Mode.ContentIsMask} name="composer-caret.png" />
        </button>
      }
      {@props.children}
    </div>

  _onDragStart: (event) =>
    json = JSON.stringify(@props.item, Utils.registeredObjectReplacer)
    event.dataTransfer.setData('nylas-token-item', json)
    event.dataTransfer.setData('text/plain', @props.item.toString())
    event.dataTransfer.dropEffect = "move"
    event.dataTransfer.effectAllowed = "move"
    @setState(dragging: true)

  _onDragEnd: (event) =>
    @setState(dragging: false)

  _onSelect: (event) =>
    @props.onSelected(@props.item)

  _onDoubleClick: (event) =>
    if @props.onEdited
      @setState(editing: true)

  _onEditKeydown: (event) =>
    if event.key in ['Escape', 'Enter']
      @_onEditFinished()

  _onEditFinished: (event) =>
    @props.onEdited?(@props.item, @state.editingValue)
    @setState(editing: false)

  _onAction: (event) =>
    @props.onAction(@props.item)
    event.preventDefault()

###
The TokenizingTextField component displays a list of options as you type
and converts them into stylable tokens.

It wraps the Menu component, which takes care of the typing and keyboard
interactions.

See documentation on the propTypes for usage info.

Section: Component Kit
###

class TokenizingTextField extends React.Component
  @displayName: "TokenizingTextField"

  @containerRequired: false

  # Exposed for tests
  @Token: Token

  @propTypes:
    className: React.PropTypes.string

    # An array of current tokens.
    #
    # A token is usually an object type like a `Contact`. The set of
    # tokens is stored as a prop instead of `state`. This means that when
    # the set of tokens needs to be changed, it is the parent's
    # responsibility to make that change.
    tokens: React.PropTypes.arrayOf(React.PropTypes.object)

    # The maximum number of tokens allowed. When null (the default) and
    # unlimited number of tokens may be given
    maxTokens: React.PropTypes.number

    # A function that, given an object used for tokens, returns a unique
    # id (key) for that object.
    #
    # This is necessary for React to assign each of the subitems and
    # unique key.
    tokenKey: React.PropTypes.func.isRequired

    # A function that, given a token, returns true if the token is valid
    # and false if the token is invalid. Useful if your implementation of
    # onAdd allows invalid tokens to be added to the field (ie malformed
    # email addresses.) Optional.
    #
    tokenIsValid: React.PropTypes.func

    # What each token looks like
    #
    # A function that is passed an object and should return React elements
    # to display that individual token.
    tokenRenderer: React.PropTypes.func.isRequired

    tokenClassNames: React.PropTypes.func

    # The function responsible for providing a list of possible options
    # given the current input.
    #
    # It takes the current input as a value and should return an array of
    # candidate objects. These objects must be the same type as are passed
    # to the `tokens` prop.
    #
    # The function may either directly return tokens, or may return a
    # Promise, that resolves with the requested tokens
    onRequestCompletions: React.PropTypes.func.isRequired

    # What each suggestion looks like.
    #
    # This is passed through to the Menu component's `itemContent` prop.
    # See components/menu.cjsx for more info.
    completionNode: React.PropTypes.func.isRequired

    # Gets called when we we're ready to add whatever it is we're
    # completing
    #
    # It's either passed an array of objects (the same ones used to
    # render tokens)
    #
    # OR
    #
    # It's passed the string currently in the input field. The string case
    # happens on paste and blur.
    #
    # The function doesn't need to return anything, but it is generally
    # responible for mutating the parent's state in a way that eventually
    # updates this component's `tokens` prop.
    onAdd: React.PropTypes.func.isRequired

    # Gets called when we remove a token
    #
    # It's passed an array of objects (the same ones used to render
    # tokens)
    #
    # The function doesn't need to return anything, but it is generally
    # responible for mutating the parent's state in a way that eventually
    # updates this component's `tokens` prop.
    onRemove: React.PropTypes.func.isRequired

    # Gets called when an existing token is double-clicked and edited.
    # Do not provide this method if you want to disable editing.
    #
    # It's passed a token index, and the new text typed in that location.
    #
    # The function doesn't need to return anything, but it is generally
    # responible for mutating the parent's state in a way that eventually
    # updates this component's `tokens` prop.
    onEdit: React.PropTypes.func

    # Called when we remove and there's nothing left to remove
    onEmptied: React.PropTypes.func

    # Called when the secondary action of the token gets invoked.
    onTokenAction: React.PropTypes.oneOfType([
      React.PropTypes.func,
      React.PropTypes.bool,
    ])

    # Called when the input is focused
    onFocus: React.PropTypes.func

    # A Prompt used in the head of the menu
    menuPrompt: React.PropTypes.string

    # A classSet hash applied to the Menu item
    menuClassSet: React.PropTypes.object

  @defaultProps:
    className: ''
    tokenClassNames: -> ''

  constructor: (@props) ->
    @state =
      inputValue: ""
      completions: []
      selectedTokenKey: null

  componentDidMount: -> @_mounted = true
  componentWillUnmount: -> @_mounted = false

  render: =>
    {Menu} = require 'nylas-component-kit'

    classSet = {}
    classSet[@props.className] = true
    classes = classNames _.extend {}, classSet, (@props.menuClassSet ? {}),
      "tokenizing-field": true
      "focused": @state.focus
      "empty": (@state.inputValue ? "").trim().length is 0

    <Menu
      className={classes}
      ref="completions"
      items={@state.completions}
      itemKey={ (item) -> item.id }
      itemContent={@props.completionNode}
      headerComponents={[@_fieldComponent()]}
      onFocus={@_onInputFocused}
      onBlur={@_onInputBlurred}
      onSelect={@_addToken}
    />

  _fieldComponent: =>
    <div key="field-component" ref="field-drop-target" onClick={@_onClick} onDrop={@_onDrop}>
      {@_renderPrompt()}
      <div className="tokenizing-field-input">
        {@_placeholder()}
        {@_fieldComponents()}
        {@_inputEl()}
      </div>
    </div>

  _inputEl: =>
    props =
      onCopy: @_onCopy
      onCut: @_onCut
      onPaste: @_onPaste
      onKeyDown: @_onInputKeydown
      onBlur: @_onInputBlurred
      onFocus: @_onInputFocused
      onChange: @_onInputChanged
      disabled: @props.disabled
      tabIndex: @props.tabIndex ? 0
      value: @state.inputValue

    # If we can't accept additional tokens, override the events that would
    # enable additional items to be inserted
    if @_atMaxTokens()
      props.className = "noop-input"
      props.onFocus = => @_onInputFocused(noCompletions: true)
      props.onPaste = => 'noop-input'
      props.onChange = => 'noop'
      props.value = ''

    <SizeToFitInput ref="input" spellCheck="false" {...props} />

  _placeholder: =>
    if not @state.focus and @props.placeholder? and @props.tokens.length is 0
      return <div className="placeholder">{@props.placeholder}</div>
    else
      return <span></span>

  _atMaxTokens: =>
    if @props.maxTokens
      @props.tokens.length >= @props.maxTokens
    else return false

  _renderPrompt: =>
    if @props.menuPrompt
      <div className="tokenizing-field-label">{"#{@props.menuPrompt}:"}</div>
    else
      <div></div>

  _fieldComponents: =>
    @props.tokens.map (item) =>
      key = @props.tokenKey(item)
      valid = true
      if @props.tokenIsValid
        valid = @props.tokenIsValid(item)

      TokenRenderer = @props.tokenRenderer
      onAction = if @props.onTokenAction is false
        null
      else
        @props.onTokenAction || @_showDefaultTokenMenu

      <Token className={@props.tokenClassNames(item)}
             item={item}
             key={key}
             valid={valid}
             selected={@state.selectedTokenKey is key}
             onSelected={@_selectToken}
             onEdited={@props.onEdit}
             onAction={onAction}>
        <TokenRenderer token={item} />
      </Token>

  # Maintaining Input State

  _onClick: (event) =>
    # Don't focus if the focus is already on an input within our field,
    # like an editable token's input
    if event.target.tagName is 'INPUT' and ReactDOM.findDOMNode(@).contains(event.target)
      return
    @focus()

  _onDrop: (event) =>
    return unless 'nylas-token-item' in event.dataTransfer.types

    try
      data = event.dataTransfer.getData('nylas-token-item')
      item = JSON.parse(data, Utils.registeredObjectReviver)
    catch err
      console.error(err)
      item = null

    if item
      @_addToken(item)

  _onInputFocused: ({noCompletions}={}) =>
    @setState(focus: true)
    @props.onFocus?()
    @_refreshCompletions() unless noCompletions

  _onInputKeydown: (event) =>
    if event.key in ["Backspace", "Delete"]
      @_removeToken()

    else if event.key in ["Escape"]
      @_refreshCompletions("", clear: true)

    else if event.key in ["Tab", "Enter"]
      @_onInputTrySubmit(event)

    else if event.keyCode is 188 # comma
      event.preventDefault() # never allow commas in the field
      @_onInputTrySubmit(event)

  _onInputTrySubmit: (event) =>
    return if (@state.inputValue ? "").trim().length is 0
    event.preventDefault()
    event.stopPropagation()
    if @state.completions.length > 0
      @_addToken(@refs.completions.getSelectedItem() || @state.completions[0])
    else
      @_addInputValue()

  _onInputChanged: (event) =>
    val = event.target.value.trimLeft()
    @setState
      selectedTokenKey: null
      inputValue: val

    # If it looks like an email, and the last character entered was a
    # space, then let's add the input value.
    # TODO WHY IS THIS EMAIL RELATED?
    if RegExpUtils.emailRegex().test(val) and _.last(val) is " "
      @_addInputValue(val[0...-1], skipNameLookup: true)
    else
      @_refreshCompletions(val)

  _onInputBlurred: (event) =>
    # Not having a relatedTarget can happen when the whole app blurs. When
    # this happens we want to leave the field as-is
    return unless event.relatedTarget

    if event.relatedTarget is ReactDOM.findDOMNode(@)
      return

    @_addInputValue()
    @_refreshCompletions("", clear: true)
    @setState
      selectedTokenKey: null
      focus: false

  _clearInput: =>
    @setState(inputValue: "")
    @_refreshCompletions("", clear: true)

  focus: =>
    @refs.input.focus()

  # Managing Tokens

  _addInputValue: (input, options={}) =>
    return if @_atMaxTokens()
    input ?= @state.inputValue
    return if input.length is 0
    @props.onAdd(input, options)
    @_clearInput()

  _selectToken: (token) =>
    @setState
      selectedTokenKey: @props.tokenKey(token)

  _selectedToken: =>
    _.find @props.tokens, (t) =>
      @props.tokenKey(t) is @state.selectedTokenKey

  _addToken: (token) =>
    return unless token
    @props.onAdd([token])
    @_clearInput()
    @focus()

  _removeToken: (token = null) =>
    if @state.inputValue.trim().length is 0 and @props.tokens.length is 0 and @props.onEmptied?
      @props.onEmptied()

    if token
      tokenToDelete = token
    else if @state.selectedTokenKey
      tokenToDelete = @_selectedToken()
    else if @props.tokens.length > 0
      @_selectToken(@props.tokens[@props.tokens.length - 1])

    if tokenToDelete
      @props.onRemove([tokenToDelete])
      if @props.tokenKey(tokenToDelete) is @state.selectedTokenKey
        @setState
          selectedTokenKey: null

  _showDefaultTokenMenu: (token) =>
    {remote} = require('electron')
    {Menu, MenuItem} = remote

    menu = new Menu()
    menu.append(new MenuItem(
      label: 'Remove',
      click: => @_removeToken(token)
    ))
    menu.popup(remote.getCurrentWindow())

  # Copy and Paste

  _onCut: (event) =>
    if @state.selectedTokenKey
      event.clipboardData?.setData('text/plain', @props.tokenKey(@_selectedToken()))
      event.preventDefault()
      @_removeToken(@_selectedToken())

  _onCopy: (event) =>
    if @state.selectedTokenKey
      event.clipboardData.setData('text/plain', @props.tokenKey(@_selectedToken()))
      event.preventDefault()

  _onPaste: (event) =>
    data = event.clipboardData.getData('text/plain')
    newInputValue = @state.inputValue + data
    if RegExpUtils.emailRegex().test(newInputValue)
      @_addInputValue(newInputValue, skipNameLookup: true)
      event.preventDefault()
    else
      @_refreshCompletions(newInputValue)


  # Managing Suggestions

  # Asks `@props.onRequestCompletions` for new completions given the
  # current inputValue. Since `onRequestCompletions` can be asynchronous,
  # this function will handle calling `setState` on `completions` when
  # `onRequestCompletions` returns.
  _refreshCompletions: (val = @state.inputValue, {clear}={}) =>
    existingKeys = _.map(@props.tokens, @props.tokenKey)
    filterTokens = (tokens) =>
      _.reject tokens, (t) => @props.tokenKey(t) in existingKeys

    tokensOrPromise = @props.onRequestCompletions(val, {clear})

    if _.isArray(tokensOrPromise)
      @setState completions: filterTokens(tokensOrPromise)
    else if tokensOrPromise instanceof Promise
      tokensOrPromise.then (tokens) =>
        return unless @_mounted
        @setState completions: filterTokens(tokens)
    else
      console.warn "onRequestCompletions returned an invalid type. It must return an Array of tokens or a Promise that resolves to an array of tokens"
      @setState completions: []

module.exports = TokenizingTextField
