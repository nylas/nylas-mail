React = require 'react/addons'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'event-kit'
{Contact, ContactStore} = require 'inbox-exports'
RetinaImg = require './retina-img'

{DragDropMixin} = require 'react-dnd'

Token = React.createClass
  mixins: [DragDropMixin]
  propTypes:
    selected: React.PropTypes.bool,
    select: React.PropTypes.func.isRequired,
    action: React.PropTypes.func,
    item: React.PropTypes.object,

  statics:
    configureDragDrop: (registerType) ->
      registerType('token', {
        dragSource:
          beginDrag: (component) ->
            item: component.props.item
      })

  render: ->
    classes = React.addons.classSet
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


module.exports =
TokenizingTextField = React.createClass
  mixins: [DragDropMixin]

  propTypes:
    className: React.PropTypes.string,
    prompt: React.PropTypes.string,
    tokens: React.PropTypes.arrayOf(React.PropTypes.object),
    tokenKey: React.PropTypes.func.isRequired,
    tokenContent: React.PropTypes.func.isRequired,
    completionContent: React.PropTypes.func.isRequired,
    completionsForInput: React.PropTypes.func.isRequired

    # called with an array of items to add
    add: React.PropTypes.func.isRequired,
    # called with an array of items to remove
    remove: React.PropTypes.func.isRequired,
    showMenu: React.PropTypes.func,

  statics:
    configureDragDrop: (registerType) ->
      registerType('token', {
        dropTarget:
          acceptDrop: (component, token) ->
            component._addToken(token)
      })

  getInitialState: ->
    completions: []
    inputValue: ""
    selectedTokenKey: null

  componentDidMount: ->
    input = @refs.input.getDOMNode()
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
    input = @refs.input.getDOMNode()
    measure = @refs.measure.getDOMNode()
    measure.innerText = @state.inputValue
    measure.style.top = input.offsetTop + "px"
    measure.style.left = input.offsetLeft + "px"
    input.style.width = "calc(4px + #{measure.offsetWidth}px)"

  render: ->
    {Menu} = require 'ui-components'

    classes = React.addons.classSet _.extend (@props.classSet ? {}),
      "tokenizing-field": true
      "focused": @state.focus
      "native-key-bindings": true
      "empty": @state.inputValue.trim().length is 0
      "has-suggestions": @state.completions.length > 0

    <Menu className={classes} ref="completions"
          items={@state.completions}
          itemKey={ (item) -> item.id }
          itemContent={@props.completionContent}
          headerComponents={[@_fieldComponent()]}
          onSelect={@_addToken}
          />

  _fieldComponent: ->
    <div key="field-component" onClick={@focus} {...@dropTargetFor('token')}>
      <div className="tokenizing-field-label">{"#{@props.prompt}:"}</div>
      <div className="tokenizing-field-input">
        {@_fieldTokenComponents()}

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
        <span ref="measure" style={
          position: 'absolute'
          visibility: 'hidden'
        }/>
      </div>
    </div>

  _fieldTokenComponents: ->
    @props.tokens.map (item) =>
      <Token item={item}
             key={@props.tokenKey(item)}
             select={@_selectToken}
             action={@props.showMenu || @_showDefaultTokenMenu}
             selected={@state.selectedTokenKey is @props.tokenKey(item)}>
        {@props.tokenContent(item)}
      </Token>

  # Maintaining Input State

  _onInputFocused: ->
    @setState
      completions: @_getCompletions()
      focus: true

  _onInputChanged: (event) ->
    val = event.target.value.trimLeft()
    @setState
      selectedTokenKey: null
      completions: @_getCompletions(val)
      inputValue: val

  _onInputBlurred: ->
    @_addInputValue()
    @setState
      selectedTokenKey: null
      focus: false

  _clearInput: ->
    @setState
      completions: []
      inputValue: ""

  focus: ->
    @refs.input.getDOMNode().focus()

  # Managing Tokens

  _addInputValue: (input) ->
    input ?= @state.inputValue
    values = input.split(/[, \n\r><]/)
    @props.add(values)
    @_clearInput()

  _selectToken: (token) ->
    @setState
      selectedTokenKey: @props.tokenKey(token)

  _selectedToken: ->
    _.find @props.tokens, (t) =>
      @props.tokenKey(t) is @state.selectedTokenKey

  _addToken: (token) ->
    return unless token
    @props.add([token])
    @_clearInput()
    @focus()

  _removeToken: (token = null) ->
    if @state.inputValue.trim().length is 0 and @props.tokens.length is 0 and @props.onRemove?
      @props.onRemove()

    if token
      tokenToDelete = token
    else if @state.selectedTokenKey
      tokenToDelete = @_selectedToken()
    else if @props.tokens.length > 0
      @_selectToken(@props.tokens[@props.tokens.length - 1])

    if tokenToDelete
      @props.remove([tokenToDelete])
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
      event.clipboardData.setData('text/plain', @props.tokenKey(@_selectedToken()))
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

  _getCompletions: (val = @state.inputValue) ->
    existingKeys = _.map(@props.tokens, @props.tokenKey)
    tokens = @props.completionsForInput(val)
    _.reject tokens, (t) => @props.tokenKey(t) in existingKeys

