React = require 'react/addons'
_ = require 'underscore-plus'
{CompositeDisposable} = require 'event-kit'
{Contact, ContactStore} = require 'inbox-exports'

ComposerParticipant = require './composer-participant.cjsx'

module.exports =
ComposerParticipants = React.createClass
  getInitialState: ->
    completions: []
    selectedIndex: 0
    currentEmail: ""

  componentDidMount: ->
    input = @refs.autocomplete.getDOMNode()
    check = (fn) -> (event) ->
      # Wrapper to guard against events triggering on the wrong element
      fn(event) if event.target == input

    @subscriptions = new CompositeDisposable()
    @subscriptions.add atom.commands.add '.autocomplete',
      'participants:move-up': (event) =>
        @_onShiftSelectedIndex(-1)
        event.preventDefault()
      'participants:move-down': (event) =>
        @_onShiftSelectedIndex(1)
        event.preventDefault()
    @subscriptions.add atom.commands.add '.autocomplete-with-suggestion',
      'participants:add-suggestion': check @_onAddSuggestion
    @subscriptions.add atom.commands.add '.autocomplete-no-suggestions',
      'participants:add-raw-email': check @_onAddRawEmail
    @subscriptions.add atom.commands.add '.autocomplete-empty',
      'participants:remove': check @_onRemoveParticipant
    @subscriptions.add atom.commands.add '.autocomplete',
      'participants:cancel': check @_onParticipantsCancel

  componentWillUnmount: ->
    @subscriptions?.dispose()

  componentDidUpdate: ->
    input = @refs.autocomplete.getDOMNode()

    # Absolutely place the completions field under the input
    comp = @refs.completions.getDOMNode()
    comp.style.top = input.offsetHeight + input.offsetTop + 6 + "px"

    # Measure the width of the text in the input
    measure = @refs.measure.getDOMNode()
    measure.innerText = @_getInputValue()
    measure.style.color = 'red'
    measure.style.top = input.offsetTop + "px"
    measure.style.left = input.offsetLeft + "px"
    width = measure.offsetWidth
    input.style.width = "calc(4px + #{width}px)"

  render: ->
    <span className={@_containerClasses()}
          onClick={@_focusOnInput}>

      <div className="participants-label">{"#{@props.placeholder}:"}</div>

      <ul className="participants">
        {@_currentParticipants()}

        <span className={@state.focus and "hasFocus" or ""}>
          <input name="add"
                 type="text"
                 ref="autocomplete"
                 onBlur={@_onBlur}
                 onFocus={@_onFocus}
                 onChange={@_onChange}
                 disabled={@props.disabled}
                 tabIndex={@props.tabIndex}
                 value={@state.currentEmail} />
          <span ref="measure" style={
            position: 'absolute'
            visibility: 'hidden'
          }/>
        </span>
      </ul>

      <ul className="completions" ref='completions' style={@_completionsDisplay()}>
        {@state.completions.map (p, i) =>
          # Add a `seen` class if this participant is already in this field.
          # We use CSS to grey it out.
          # Add a `selected` class for the current selection.
          # We use this instead of :hover so we can update selection with
          # either mouse or keyboard.
          classes = (_.compact [
            p.email in _.pluck(@props.participants, 'email') and "seen",
            (i+1) == @state.selectedIndex and 'selected'
            ]).join " "
          <li
            onMouseOver={=> @setState {selectedIndex: i+1}}
            onMouseOut={=> @setState {selectedIndex: 0}}
            onMouseDown={=> @_onMouseDown(p)}
            onMouseUp={=> @_onMouseUp(p)}
            key={"li-#{p.id}"}
            className={classes}
            ><ComposerParticipant key={p.id} participant={p}/></li>}
      </ul>

    </span>

  _currentParticipants: ->
    @props.participants?.map (participant) =>
      <li key={"participant-li-#{participant.id}"}
          className={@_participantHoverClass(participant)}>
        <ComposerParticipant key={"participant-#{participant.id}"}
                             participant={participant}
                             onRemove={@props.participantFunctions.remove}/>
      </li>

  _participantHoverClass: (participant) ->
    React.addons.classSet
      "hover": @_selected()?.email is participant.email

  _containerClasses: ->
    React.addons.classSet
      "autocomplete": true
      "increase-css-specificity": true
      "autocomplete-empty": @state.currentEmail.trim().length is 0
      "autocomplete-no-suggestions": @_noSuggestions()
      "autocomplete-with-suggestion": @state.completions.length > 0
      "autocomplete-looks-like-raw-email": @_looksLikeRawEmail()

  _noSuggestions: ->
    @state.completions.length is 0 and @state.currentEmail.trim().length > 0

  _onBlur: ->
    if @_cancelBlur then return
    @_onAddRawEmail() if @_looksLikeRawEmail()
    @setState
      focus: false
      selectedIndex: 0

  _onParticipantsCancel: ->
    @setState focus: false
    @_clearSuggestions()
    @refs.autocomplete.getDOMNode().blur()

  _onFocus: ->
    @_reloadSuggestions()
    @setState focus: true

  _onMouseDown: ->
    @_cancelBlur = true

  _onMouseUp: (participant) ->
    @_cancelBlur = false
    if participant?
      @_addParticipant(participant)
      # since the controlled input hasn't re-rendered yet, but we're
      # going to fire a focus
      @refs.autocomplete.getDOMNode().value = ""
      @_focusOnInput()

  _completionsDisplay: ->
    if @state.completions.length > 0 and @state.focus
      display: "initial"
    else
      display: "none"

  _focusOnInput: ->
    @refs.autocomplete.getDOMNode().focus()

  _selected: ->
    if @state.selectedIndex > 0 and @state.selectedIndex <= @state.completions.length
      @state.completions[@state.selectedIndex - 1]
    else
      undefined

  _onChange: (event) ->
    @_reloadSuggestions()

  _looksLikeRawEmail: ->
    emailIsh = /.+@.+\..+/.test(@state.currentEmail.trim())
    @state.completions.length is 0 and emailIsh

  _onShiftSelectedIndex: (count) ->
    newIndex = @state.selectedIndex + count
    mod = @state.completions.length + 1
    if (newIndex < 1)
      newIndex = mod - (1 - (newIndex % mod))
    else
      if newIndex % mod is 0
        newIndex = 1
      else
        newIndex = newIndex % mod
    @setState
      selectedIndex: newIndex

  _onAddSuggestion: ->
    participant = @_selected()
    @_addParticipant(participant) if participant

  _onAddRawEmail: ->
    participants = (ContactStore.searchContacts(@_getInputValue()) ? [])
    if participants[0]
      @_addParticipant(participants[0])
    else
      newParticipant = new Contact(email: @_getInputValue())
      @_addParticipant(newParticipant)

  _addParticipant: (participant) ->
    return if participant.email in _.pluck(@props.participants, 'email')
    @props.participantFunctions.add participant
    @_clearSuggestions()

  _onRemoveParticipant: ->
    if @props.participants.length > 0
      @_removeParticipant _.last(@props.participants)

  _removeParticipant: (participant) ->
    @props.participantFunctions.remove participant

  _clearSuggestions: ->
    @setState
      completions: []
      selectedIndex: 0
      currentEmail: ""

  _reloadSuggestions: ->
    val = @_getInputValue()

    if val.length is 0 then completions = []
    else completions = ContactStore.searchContacts val

    @setState
      completions: completions
      currentEmail: val
      selectedIndex: 1

  _getInputValue: ->
    (@refs.autocomplete.getDOMNode().value ? "").trimLeft()
