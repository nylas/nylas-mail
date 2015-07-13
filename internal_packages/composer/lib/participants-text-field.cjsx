React = require 'react'
_ = require 'underscore'

{Contact, ContactStore} = require 'nylas-exports'
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

  @defaultProps:
    visible: true

  render: =>
    classSet = {}
    classSet[@props.field] = true
    <div className="participants-text-field" style={zIndex: 1000-@props.tabIndex, display: 'inline'}>
      <TokenizingTextField
        ref="textField"
        tokens={@props.participants[@props.field]}
        tokenKey={ (p) -> p.email }
        tokenNode={@_tokenNode}
        onRequestCompletions={ (input) -> ContactStore.searchContacts(input) }
        completionNode={@_completionNode}
        onAdd={@_add}
        onRemove={@_remove}
        onEmptied={@props.onEmptied}
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
        <span className="participant-secondary">({p.email})</span>
      </div>
    else
      <div className="participant">
        <span className="participant-primary">{p.email}</span>
      </div>


  _remove: (values) =>
    field = @props.field
    updates = {}
    updates[field] = _.reject @props.participants[field], (p) ->
      return true if p.email in values
      return true if p.email in _.map values, (o) -> o.email
      false
    @props.change(updates)

  _add: (values, options={}) =>
    # If the input is a string, parse out email addresses and build
    # an array of contact objects. For each email address wrapped in
    # parentheses, look for a preceding name, if one exists.

    if _.isString(values)
      values = ContactStore.parseContactsInString(values, options)

    # Safety check: remove anything from the incoming values that isn't
    # a Contact. We should never receive anything else in the values array.

    values = _.compact _.map values, (value) ->
      if value instanceof Contact
        return value
      else
        return null

    updates = {}
    for field in Object.keys(@props.participants)
      updates[field] = [].concat(@props.participants[field])

    for value in values
      # first remove the participant from all the fields. This ensures
      # that drag and drop isn't "drag and copy." and you can't have the
      # same recipient in multiple places.
      for field in Object.keys(@props.participants)
        updates[field] = _.reject updates[field], (p) ->
          p.email is value.email

      # add the participant to field
      updates[@props.field] = _.union(updates[@props.field], [value])

    @props.change(updates)
    ""

  _showContextMenu: (participant) =>
    remote = require('remote')

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
