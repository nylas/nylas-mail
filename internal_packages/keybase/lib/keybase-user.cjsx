{Utils, React, Actions, ReactDOM} = require 'nylas-exports'
{ParticipantsTextField} = require 'nylas-component-kit'
PGPKeyStore = require './pgp-key-store'
kb = require './keybase'
_ = require 'underscore'

class EmailPopover extends React.Component
  constructor: ->
    @state = {to: [], cc: [], bcc: []}

  render: ->
    participants = @state

    <div className="keybase-import-popover">
      <span className="title">
        Associate Emails with Key
      </span>
      <ParticipantsTextField
        field="to"
        className="keybase-participant-field"
        participants={ participants }
        change={ @_onRecipientFieldChange } />
      <button className="btn btn-toolbar" onClick={ @_onDone }>Done</button>
    </div>

  _onRecipientFieldChange: (contacts) =>
    @setState(contacts)

  _onDone: =>
    @props.onPopoverDone _.pluck(@state.to, 'email')
    Actions.closePopover()


module.exports =
class KeybaseUser extends React.Component
  @displayName: 'KeybaseUserProfile'

  @propTypes:
    profile: React.PropTypes.object.isRequired

  constructor: (props) ->
    super(props)
    # should the "new email" list component be an input, or a button?
    @state = {inputEmail: false}

  _matchKeys: (targetKey, keys) =>
    # given a single key to match, and an array of keys to match from, returns
    # a key from the array with the same fingerprint as the target key, or null
    if not targetKey.key?
      return null

    key = _.find(keys, (key) =>
      # not sure if the toString is necessary?
      return key.key? and key.key.get_pgp_fingerprint().toString('hex') == targetKey.key.get_pgp_fingerprint().toString('hex')
    )

    if key == undefined
      return null
    else
      return key

  _importKey: =>
    # opens a popover requesting user to enter 1+ emails to associate with a
    # key - a button in the popover then calls _save to actually import the key
    #popoverTarget = ReactDOM.findDOMNode(@refs.button).getBoundingClientRect()
    popoverTarget = ReactDOM.findDOMNode(@refs.button).getBoundingClientRect()

    Actions.openPopover(
      <EmailPopover onPopoverDone={ @_popoverDone } />,
      {originRect: popoverTarget, direction: 'left'}
    )

  _popoverDone: (addresses) =>
    # closes the popover, saves a key if an email was entered
    {profile} = @props
    keybaseUsername = profile.keybase_user.components.username.val

    if addresses.length < 1
      # no email addresses added, nop
      return
    else
      @_save(keybaseUsername, addresses[0])

    if addresses.length > 1
      # add any extra ddresses the user entered
      _.each(addresses.slice(1), (address) =>
        @_addEmail(address)
      )

  _save: (keybaseUsername, address) =>
    # save/import a key from keybase
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error "Unable to fetch key for #{keybaseUsername}"
      else
        PGPKeyStore.saveNewKey(address, key, true) # isPub = true
    )
    return

  _delete: (event) =>
    # delete a locally saved key
    email = event.target.attributes['data-email'].value
    keys = PGPKeyStore.pubKeys(email)
    if keys? and keys.length == 1
      key = keys[0]
    else if keys.length > 1
      # TODO key metadata objects need a unique ID
      key = @_matchKeys(@props.profile.key, keys)
      #console.error "Multiple keys associated with #{email}, unable to determine which to remove from"

    if key?
      PGPKeyStore.deleteKey(key)
    else
      console.error "Unable to fetch key for #{email}"

  _addEmail: (email) =>
    # associate another email address with this key
    PGPKeyStore.addAddressToKey(@props.profile, email)

  _addEmailInput: (contacts) =>
    # when a new email is added to the list of emails
    # flow is (click "add email") -> _addEmailClick -> (enter email) -> this
    emails = _.pluck(contacts.to, 'email')
    _.each(emails, @_addEmail)
    @setState({inputEmail: false})

  _addEmailClick: (event) =>
    # create a text field in which to enter a new email to associate with a key
    @setState({inputEmail: true})
    # TODO focus on the new field
    # React.findDOMNode(@refs.addNewEmail).focus()

  _removeEmailClick: (event) =>
    email = event.target.attributes['data-email'].value
    @_removeEmail(email)

  _removeEmail: (email) =>
    console.log @props.profile
    PGPKeyStore.removeAddressFromKey(@props.profile, email)

  render: =>
    {profile} = @props

    keybaseDetails = null
    if profile.keybase_user?
      keybase = profile.keybase_user
      # username
      username = keybase.components.username.val

      # full name
      if keybase.components.full_name?.val?
        fullname = keybase.components.full_name.val
      else
        fullname = username

      # profile picture
      if keybase.thumbnail?
        picture = keybase.thumbnail
      else
        picture = "#"
        # TODO default picture

      # various web accounts/profiles
      possible_profiles = ["twitter", "github", "coinbase"]
      profiles = _.map(possible_profiles, (possible) =>
        if keybase.components[possible]?.val?
          return "#{possible}: #{keybase.components[possible].val}"
      )
      profiles = _.reject(profiles, (profile) -> profile is undefined)

      if profiles.length > 0
        profiles =  _.map(profiles, (profile) ->
          return <li>{ profile }</li>)
        profileList = (<ul>{ profiles }</ul>)
      else
        profileList = null

      keybaseDetails = (<div className="details">
        <h2>
          { fullname }&nbsp;
          <small className="profile-username">
            ({ username })
          </small>
        </h2>

        { profileList }
      </div>)

    # button to save/delete key
    if profile.addresses?.length > 0
      # TODO what about the other email(s) that might be in the list?
      saved = PGPKeyStore.pubKeys(profile.addresses[0])
    else
      # can't possibly have them saved if we have no email for them
      saved = false
    if not saved
      saveDeleteButton = (<button title="Import" className="btn btn-toolbar" onClick={ @_importKey } ref="button">
        Import Key
      </button>
      )
    else
      saveDeleteButton = (<button title="Delete" className="btn btn-toolbar btn-danger" data-email={ profile.addresses[0] } onClick={ @_delete } ref="button">
        Delete Key
      </button>
      )

    # email addresses
    if profile.addresses?.length > 0
      emails = _.map(profile.addresses, (email) =>
        # TODO make that remove button not terrible
        return <li>{ email } <small><a onClick={ @_removeEmailClick } data-email={email}>(X)</a></small></li>)

      if @state.inputEmail
        participants = {to: [], cc: [], bcc: []}
        emailList = (<ul> { emails }
            <ParticipantsTextField
              field="to"
              ref="addNewEmail"
              className="keybase-participant-field"
              participants={ participants }
              change={ @_addEmailInput } />
            </ul>)
      else
        emailList = (<ul> { emails }
            <a ref="addEmail" onClick={ @_addEmailClick }>+ Add Email</a>
            </ul>)

    <div className="keybase-profile">
      <img className="user-picture" src={ picture }/>
      { keybaseDetails }
      <div className="email-list">
        <ul>
          { emailList }
        </ul>
      </div>

        { saveDeleteButton }
    </div>
