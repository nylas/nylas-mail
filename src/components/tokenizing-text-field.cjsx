React = require 'react/addons'
classNames = require 'classnames'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'event-kit'
{Contact, ContactStore} = require 'inbox-exports'
RetinaImg = require './retina-img'

{DragDropMixin} = require 'react-dnd'

Token = React.createClass
  displayName: "Token"

  mixins: [DragDropMixin]

  propTypes:
    selected: React.PropTypes.bool,
    select: React.PropTypes.func.isRequired,
    action: React.PropTypes.func,
    item: React.PropTypes.object,

  statics:
    configureDragDrop: (registerType) =>
      registerType('token', {
        dragSource:
          beginDrag: (component) =>
            item: component.props.item
      })

  render: ->
    classes = classNames
      "token": true
      "dragging": @getDragState('token').isDragging
      "selected": @props.selected

    <div {...@dragSourceFor('token')}
         className={classes}
         onClick={@_onSelect}>
      <button className="action" onClick={@_onAction} style={marginTop: "2px"}><RetinaImg name="composer-caret.png" /></button>
      {@props.children}
    </div>

  _onSelect: (event) ->
    @props.select(@props.item)
    event.preventDefault()

  _onAction: (event) ->
    @props.action(@props.item)
    event.preventDefault()

###
The TokenizingTextField component displays a list of options as you type
and converts them into stylable tokens.

It wraps the Menu component, which takes care of the typing and keyboard
interactions.

See documentation on the propTypes for usage info.

Section: Component Kit
###
TokenizingTextField = React.createClass
  displayName: "TokenizingTextField"

  propTypes:
    # An array of current tokens.
    #
    # A token is usually an object type like a
    # `Contact` or a `SalesforceObject`. The set of tokens is stored as a
    # prop instead of `state`. This means that when the set of tokens
    # needs to be changed, it is the parent's responsibility to make that
    # change.
    tokens: React.PropTypes.arrayOf(React.PropTypes.object)

    # The maximum number of tokens allowed. When null (the default) and
    # unlimited number of tokens may be given
    maxTokens: React.PropTypes.number

    # A unique ID for each token object
    #
    # A function that, given an object used for tokens, returns a unique
    # id (key) for that object.
    #
    # This is necessary for React to assign each of the subitems and
    # unique key.
    tokenKey: React.PropTypes.func.isRequired

    # What each token looks like
    #
    # A function that is passed an object and should return React elements
    # to display that individual token.
    tokenNode: React.PropTypes.func.isRequired

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

    # By default, when blurred, whatever is in the field is added. If this
    # is true, the field will be cleared instead.
    clearOnBlur: React.PropTypes.bool

    # Gets called when we remove a token
    #
    # It's passed an array of objects (the same ones used to render
    # tokens)
    #
    # The function doesn't need to return anything, but it is generally
    # responible for mutating the parent's state in a way that eventually
    # updates this component's `tokens` prop.
    onRemove: React.PropTypes.func.isRequired

    # Called when we remove and there's nothing left to remove
    onEmptied: React.PropTypes.func

    # Gets called when the secondary action of the token gets invoked.
    onTokenAction: React.PropTypes.func

    # The tabIndex of the input item
    tabIndex: React.PropTypes.oneOfType([
      React.PropTypes.number
      React.PropTypes.string
    ])

    # A Prompt used in the head of the menu
    menuPrompt: React.PropTypes.string

    # A classSet hash applied to the Menu item
    menuClassSet: React.PropTypes.object

  mixins: [DragDropMixin]

  statics:
    configureDragDrop: (registerType) =>
      registerType('token', {
        dropTarget:
          acceptDrop: (component, token) =>
            component._addToken(token)
      })

  getInitialState: ->
    inputValue: ""
    completions: []
    selectedTokenKey: null

  componentDidMount: ->
    input = React.findDOMNode(@refs.input)
    check = (fn) -> (event) ->
      return unless event.target is input
      # Wrapper to guard against events triggering on the wrong element
      fn(event)

    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add '.tokenizing-field',
      'tokenizing-field:cancel': check => @_clearInput()
      'tokenizing-field:remove': check => @_removeToken()
      'tokenizing-field:add-suggestion': check => @_addToken(@refs.completions.getSelectedItem() || @state.completions[0])
      'tokenizing-field:add-input-value': check => @_addInputValue()

  componentWillUnmount: ->
    @subscriptions?.dispose()

  componentDidUpdate: ->
    # Measure the width of the text in the input and
    # resize the input field to fit.
    input = React.findDOMNode(@refs.input)
    measure = React.findDOMNode(@refs.measure)
    measure.innerText = @state.inputValue
    measure.style.top = input.offsetTop + "px"
    measure.style.left = input.offsetLeft + "px"
    if @_atMaxTokens()
      input.style.width = "4px"
    else
      input.style.width = "calc(6px + #{measure.offsetWidth}px)"

  render: ->
    {Menu} = require 'ui-components'

    classes = classNames _.extend (@props.menuClassSet ? {}),
      "tokenizing-field": true
      "focused": @state.focus
      "native-key-bindings": true
      "empty": (@state.inputValue ? "").trim().length is 0
      "has-suggestions": @state.completions.length > 0

    <Menu className={classes} ref="completions"
          items={@state.completions}
          itemKey={ (item) -> item.id }
          itemContent={@props.completionNode}
          headerComponents={[@_fieldComponent()]}
          onSelect={@_addToken}
          />

  _fieldComponent: ->
    <div key="field-component" onClick={@focus} {...@dropTargetFor('token')}>
      {@_renderPrompt()}
      <div className="tokenizing-field-input">
        {@_fieldTokenComponents()}

        {@_inputEl()}
        <span ref="measure" style={
          position: 'absolute'
          visibility: 'hidden'
        }/>
      </div>
    </div>

  _inputEl: ->
    if @_atMaxTokens()
      <input type="text"
             ref="input"
             className="noop-input"
             onCopy={@_onCopy}
             onCut={@_onCut}
             onBlur={@_onInputBlurred}
             onFocus={ => @_onInputFocused(noCompletions: true)}
             onChange={ -> "noop" }
             tabIndex={@props.tabIndex}
             value="" />
    else
      <input type="text"
             ref="input"
             onCopy={@_onCopy}
             onCut={@_onCut}
             onPaste={@_onPaste}
             onBlur={@_onInputBlurred}
             onFocus={@_onInputFocused}
             onChange={@_onInputChanged}
             disabled={@props.disabled}
             tabIndex={@props.tabIndex}
             value={@state.inputValue} />

  _atMaxTokens: ->
    if @props.maxTokens
      @props.tokens.length >= @props.maxTokens
    else return false

  _renderPrompt: ->
    if @props.menuPrompt
      <div className="tokenizing-field-label">{"#{@props.menuPrompt}:"}</div>
    else
      <div></div>

  _fieldTokenComponents: ->
    @props.tokens.map (item) =>
      <Token item={item}
             key={@props.tokenKey(item)}
             select={@_selectToken}
             action={@props.onTokenAction || @_showDefaultTokenMenu}
             selected={@state.selectedTokenKey is @props.tokenKey(item)}>
        {@props.tokenNode(item)}
      </Token>

  # Maintaining Input State

  _onInputFocused: ({noCompletions}={}) ->
    @setState focus: true
    @_refreshCompletions() unless noCompletions

  _onInputChanged: (event) ->
    val = event.target.value.trimLeft()
    @setState
      selectedTokenKey: null
      inputValue: val
    @_refreshCompletions(val)

  _onInputBlurred: ->
    if @props.clearOnBlur
      @_clearInput()
    else
      @_addInputValue()
    @_refreshCompletions("", clear: true)
    @setState
      selectedTokenKey: null
      focus: false

  _clearInput: ->
    @setState inputValue: ""
    @_refreshCompletions("", clear: true)

  focus: ->
    React.findDOMNode(@refs.input).focus()

  # Managing Tokens

  _addInputValue: (input) ->
    return if @_atMaxTokens()
    input ?= @state.inputValue
    @props.onAdd(input)
    @_clearInput()

  _selectToken: (token) ->
    @setState
      selectedTokenKey: @props.tokenKey(token)

  _selectedToken: ->
    _.find @props.tokens, (t) =>
      @props.tokenKey(t) is @state.selectedTokenKey

  _addToken: (token) ->
    return unless token
    @props.onAdd([token])
    @_clearInput()
    @focus()

  _removeToken: (token = null) ->
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

  _showDefaultTokenMenu: (token) ->
    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new Menu()
    menu.append(new MenuItem(
      label: 'Remove',
      click: => @_removeToken(token)
    ))

    menu.popup(remote.getCurrentWindow())

  # Copy and Paste

  _onCut: (event) ->
    if @state.selectedTokenKey
      event.clipboardData?.setData('text/plain', @props.tokenKey(@_selectedToken()))
      event.preventDefault()
      @_removeToken(@_selectedToken())

  _onCopy: (event) ->
    if @state.selectedTokenKey
      event.clipboardData.setData('text/plain', @props.tokenKey(@_selectedToken()))
      event.preventDefault()

  _onPaste: (event) ->
    data = event.clipboardData.getData('text/plain')
    @_addInputValue(data)
    event.preventDefault()

  # Managing Suggestions

  # Asks `@props.onRequestCompletions` for new completions given the
  # current inputValue. Since `onRequestCompletions` can be asynchronous,
  # this function will handle calling `setState` on `completions` when
  # `onRequestCompletions` returns.
  _refreshCompletions: (val = @state.inputValue, {clear}={}) ->
    existingKeys = _.map(@props.tokens, @props.tokenKey)
    filterTokens = (tokens) =>
      _.reject tokens, (t) => @props.tokenKey(t) in existingKeys

    tokensOrPromise = @props.onRequestCompletions(val, {clear})

    if _.isArray(tokensOrPromise)
      @setState completions: filterTokens(tokensOrPromise)
    else if tokensOrPromise instanceof Promise
      tokensOrPromise.then (tokens) =>
        return unless @isMounted()
        @setState completions: filterTokens(tokens)
    else
      console.warn "onRequestCompletions returned an invalid type. It must return an Array of tokens or a Promise that resolves to an array of tokens"
      @setState completions: []

module.exports = TokenizingTextField
