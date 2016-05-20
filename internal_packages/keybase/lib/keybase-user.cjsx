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
    displayEmailList: React.PropTypes.bool

  @defaultProps:
    actionButton: false
    displayEmailList: true

  constructor: (props) ->
    super(props)
    # should the "new email" list component be an input, or a button?
    @state = {inputEmail: false}

  componentDidMount: ->
    PGPKeyStore.getKeybaseData(@props.profile)

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

    keybaseDetails = <div className="details"></div>
    if profile.keybase_profile?
      keybase = profile.keybase_profile

      # profile picture
      if keybase.thumbnail?
        picture = <img className="user-picture" src={ keybase.thumbnail }/>
      else
        hue = Utils.hueForString("Keybase")
        bgColor = "hsl(#{hue}, 50%, 45%)"
        abv = "K"
        picture = <div className="default-profile-image" style={{backgroundColor: bgColor}}>{abv}</div>

      # full name
      if keybase.components.full_name?.val?
        fullname = keybase.components.full_name.val
      else
        fullname = username
        username = false

      # link to keybase profile
      keybase_url = "keybase.io/#{keybase.components.username.val}"
      if keybase_url.length > 25
        keybase_string = keybase_url.slice(0, 23).concat('...')
      else
        keybase_string = keybase_url
      username = <a href="https://#{keybase_url}">{keybase_string}</a>

      # TODO: potentially display confirmation on keybase-user objects
      ###
      possible_profiles = ["twitter", "github", "coinbase"]
      profiles = _.map(possible_profiles, (possible) =>
        if keybase.components[possible]?.val?
          # TODO icon instead of weird "service: username" text
          return (<span key={ possible }><b>{ possible }</b>: { keybase.components[possible].val }</span>)
      )
      profiles = _.reject(profiles, (profile) -> profile is undefined)

      profiles =  _.map(profiles, (profile) ->
        return <span key={ profile.key }>{ profile } </span>)
      profileList = (<span>{ profiles }</span>)
      ###

      keybaseDetails = (<div className="details">
        <div className="profile-name">
        { fullname }
        </div>
        <div className="profile-username">
          { username }
        </div>
      </div>)
    else
      # if no keybase profile, default image is based on email address
      hue = Utils.hueForString(@props.profile.addresses[0])
      bgColor = "hsl(#{hue}, 50%, 45%)"
      abv = @props.profile.addresses[0][0].toUpperCase()
      picture = <div className="default-profile-image" style={{backgroundColor: bgColor}}>{abv}</div>

    # email addresses
    if profile.addresses?.length > 0
      emails = _.map(profile.addresses, (email) =>
        # TODO make that remove button not terrible
        return <li key={ email }>{ email } <small><a onClick={ => @_removeEmail(email) }>(X)</a></small></li>)

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

    emailListDiv = (<div className="email-list">
        <ul>
          { emailList }
        </ul>
      </div>)

    <div className="keybase-profile">
      <div className="profile-photo-wrap">
        <div className="profile-photo">
        { picture }
        </div>
      </div>
      { keybaseDetails }
      {if @props.displayEmailList then emailListDiv}
      { @props.actionButton }
    </div>
