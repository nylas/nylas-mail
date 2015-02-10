React = require 'react'
_ = require 'underscore-plus'

{Contact,
 ContactStore} = require 'inbox-exports'
{TokenizingTextField} = require 'ui-components'

module.exports =
ParticipantsTextField = React.createClass
  displayName: 'ParticipantsTextField'

  propTypes:
    # The tab index of the ParticipantsTextField
    tabIndex: React.PropTypes.string,

    # The name of the field, used for both display purposes and also
    # to modify the `participants` provided.
    field: React.PropTypes.string,

    # Whether or not the field should be visible. Defaults to true.
    visible: React.PropTypes.bool

    # An object containing arrays of participants. Typically, this is
    # {to: [], cc: [], bcc: []}. Each ParticipantsTextField needs all of
    # the values, because adding an element to one field may remove it
    # from another.
    participants: React.PropTypes.object.isRequired,

    # The function to call with an updated `participants` object when
    # changes are made.
    change: React.PropTypes.func.isRequired,

  getDefaultProps: ->
    visible: true

  render: ->
    <div className="compose-participants-wrap" style={display: @props.visible and 'inline' or 'none'}>
      <TokenizingTextField
        ref="textField"
        prompt={@props.field}
        tabIndex={@props.tabIndex}
        tokens={@props.participants[@props.field]}
        tokenKey={ (p) -> p.email }
        tokenContent={@_componentForParticipant}
        completionsForInput={ (input) -> ContactStore.searchContacts(input) }
        completionContent={ (p) -> "#{p.name} (#{p.email})" }
        add={@_add}
        remove={@_remove}
        showMenu={@_showContextMenu} />
    </div>

  # Public. Can be called by any component that has a ref to this one to
  # focus the input field.
  focus: -> @refs.textField.focus()

  _componentForParticipant: (p) ->
    if p.name?.length > 0
      content = p.name
    else
      content = p.email

    <div className="participant">
      <span>{content}</span>
    </div>

  _remove: (participant) ->
    field = @props.field
    updates = {}
    updates[field] = _.reject @props.participants[field], (p) ->
      p.email is participant.email
    @props.change(updates)

  _add: (value) ->
    if _.isString(value)
      value = value.trim()
      return unless /.+@.+\..+/.test(value)
      value = new Contact(email: value, name: value)

    updates = {}

    # first remove the participant from all the fields. This ensures
    # that drag and drop isn't "drag and copy." and you can't have the
    # same recipient in multiple places.
    for otherField in Object.keys(@props.participants)
      updates[otherField] = _.reject @props.participants[otherField], (p) ->
        p.email is value.email

    # add the participant to field
    field = @props.field
    updates[field] = _.union (updates[field] ? []), [value]
    @props.change(updates)
    ""

  _showContextMenu: (participant) ->
    remote = require('remote')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')

    menu = new Menu()
    menu.append(new MenuItem(
      label: participant.email
      click: -> require('clipboard').writeText(participant.email)
    ))
    menu.append(new MenuItem(
      type: 'separator'
    ))
    menu.append(new MenuItem(
      label: 'Remove',
      click: => @_remove(participant)
    ))
    menu.popup(remote.getCurrentWindow())

