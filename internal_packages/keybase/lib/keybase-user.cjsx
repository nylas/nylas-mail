{Utils, React, Actions} = require 'nylas-exports'
{ParticipantsTextField} = require 'nylas-component-kit'
PGPKeyStore = require './pgp-key-store'
Identity = require './identity'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class KeybaseUser extends React.Component
  @displayName: 'KeybaseUserProfile'

  @propTypes:
    profile: React.PropTypes.instanceOf(Identity).isRequired
    actionButton: React.PropTypes.node

  @defaultProps:
    actionButton: false

  constructor: (props) ->
    super(props)
    # should the "new email" list component be an input, or a button?
    @state = {inputEmail: false}

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

  _removeEmail: (email) =>
    PGPKeyStore.removeAddressFromKey(@props.profile, email)

  render: =>
    {profile} = @props

    keybaseDetails = null
    if profile.keybase_profile?
      keybase = profile.keybase_profile
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

    # email addresses
    if profile.addresses?.length > 0
      emails = _.map(profile.addresses, (email) =>
        # TODO make that remove button not terrible
        return <li>{ email } <small><a onClick={ => @_removeEmail(email) }>(X)</a></small></li>)

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

      { @props.actionButton }
    </div>
