React = require 'react'
_ = require 'underscore'

{Utils, Contact, ContactStore} = require 'nylas-exports'
{TokenizingTextField, Menu} = require 'nylas-component-kit'

class ParticipantsTextField extends React.Component
  @displayName: 'ParticipantsTextField'

  @propTypes:
    # The tab index of the ParticipantsTextField
    tabIndex: React.PropTypes.string,

    # The name of the field, used for both display purposes and also
    # to modify the `participants` provided.
    field: React.PropTypes.string,

    # An object containing arrays of participants. Typically, this is
    # {to: [], cc: [], bcc: []}. Each ParticipantsTextField needs all of
    # the values, because adding an element to one field may remove it
    # from another.
    participants: React.PropTypes.object.isRequired,

    # The function to call with an updated `participants` object when
    # changes are made.
    change: React.PropTypes.func.isRequired,

    className: React.PropTypes.string

    onEmptied: React.PropTypes.func

    onFocus: React.PropTypes.func

    # We need to know if the draft is ready so we can enable and disable
    # ParticipantTextFields.
    #
    # It's possible for a ParticipantTextField, before the draft is
    # ready, to start the request to `add`, `remove`, or `edit`. This
    # happens when there are multiple drafts rendering, each requesting
    # focus. A blur event gets fired before the draft is loaded, causing
    # logic to run that sets an empty field. These requests are
    # asynchronous. They may resolve after the draft is in fact ready.
    # This is bad because the desire to `remove` participants may have
    # been made with an empty, non-loaded draft, but executed on the new
    # draft that was loaded in the time it took the async request to
    # return.
    draftReady: React.PropTypes.bool

  @defaultProps:
    visible: true
    draftReady: false

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  render: =>
    classSet = {}
    classSet[@props.field] = true
    <div className={@props.className}>
      <TokenizingTextField
        ref="textField"
        tokens={@props.participants[@props.field]}
        tokenKey={ (p) -> p.email }
        tokenIsValid={ (p) -> ContactStore.isValidContact(p) }
        tokenNode={@_tokenNode}
        onRequestCompletions={ (input) -> ContactStore.searchContacts(input) }
        completionNode={@_completionNode}
        onAdd={@_add}
        onRemove={@_remove}
        onEdit={@_edit}
        onEmptied={@props.onEmptied}
        onFocus={@props.onFocus}
        onTokenAction={@_showContextMenu}
        tabIndex={@props.tabIndex}
        menuClassSet={classSet}
        menuPrompt={@props.field}
        />
    </div>

  # Public. Can be called by any component that has a ref to this one to
  # focus the input field.
  focus: => @refs.textField.focus()

  _completionNode: (p) =>
    <Menu.NameEmailItem name={p.name} email={p.email} />

  _tokenNode: (p) =>
    if p.name?.length > 0 and p.name isnt p.email
      <div className="participant">
        <span className="participant-primary">{p.name}</span>&nbsp;&nbsp;
      </div>
    else
      <div className="participant">
        <span className="participant-primary">{p.email}</span>
      </div>

  _tokensForString: (string, options = {}) =>
    # If the input is a string, parse out email addresses and build
    # an array of contact objects. For each email address wrapped in
    # parentheses, look for a preceding name, if one exists.
    if string.length is 0
      return Promise.resolve([])

    ContactStore.parseContactsInString(string, options).then (contacts) =>
      if contacts.length > 0
        return Promise.resolve(contacts)
      else
        # If no contacts are returned, treat the entire string as a single
        # (malformed) contact object.
        return [new Contact(email: string, name: null)]

  _remove: (values) =>
    return unless @props.draftReady
    field = @props.field
    updates = {}
    updates[field] = _.reject @props.participants[field], (p) ->
      return true if p.email in values
      return true if p.email in _.map values, (o) -> o.email
      false
    @props.change(updates)

  _edit: (token, replacementString) =>
    return unless @props.draftReady
    field = @props.field
    tokenIndex = @props.participants[field].indexOf(token)
    @_tokensForString(replacementString).then (replacements) =>
      updates = {}
      updates[field] = [].concat(@props.participants[field])
      updates[field].splice(tokenIndex, 1, replacements...)
      @props.change(updates)

  _add: (values, options={}) =>
    # It's important we return here (as opposed to ignoring the
    # `@props.change` callback) because this method is asynchronous.
    #
    # The `tokensPromise` may be formed with an empty draft, but resolved
    # after a draft was prepared. This would cause the bad data to be
    # propagated.
    return unless @props.draftReady

    # If the input is a string, parse out email addresses and build
    # an array of contact objects. For each email address wrapped in
    # parentheses, look for a preceding name, if one exists.
    if _.isString(values)
      tokensPromise = @_tokensForString(values, options)
    else
      tokensPromise = Promise.resolve(values)

    tokensPromise.then (tokens) =>
      # Safety check: remove anything from the incoming tokens that isn't
      # a Contact. We should never receive anything else in the tokens array.
      tokens = _.filter tokens, (value) -> value instanceof Contact

      updates = {}
      for field in Object.keys(@props.participants)
        updates[field] = [].concat(@props.participants[field])

      for token in tokens
        # first remove the participant from all the fields. This ensures
        # that drag and drop isn't "drag and copy." and you can't have the
        # same recipient in multiple places.
        for field in Object.keys(@props.participants)
          updates[field] = _.reject updates[field], (p) ->
            p.email is token.email

        # add the participant to field
        updates[@props.field] = _.union(updates[@props.field], [token])

      @props.change(updates)
    return ""

  _showContextMenu: (participant) =>
    {remote} = require('electron')

    # Warning: Menu is already initialized as Menu.cjsx!

    MenuClass = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new MenuClass()
    menu.append(new MenuItem(
      label: "Copy #{participant.email}"
      click: => require('clipboard').writeText(participant.email)
    ))
    menu.append(new MenuItem(
      type: 'separator'
    ))
    menu.append(new MenuItem(
      label: 'Remove',
      click: => @_remove([participant])
    ))
    menu.popup(remote.getCurrentWindow())


module.exports = ParticipantsTextField
