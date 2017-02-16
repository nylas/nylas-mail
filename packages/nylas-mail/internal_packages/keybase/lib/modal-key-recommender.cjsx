{Utils, React, Actions} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseSearch = require './keybase-search'
KeybaseUser = require './keybase-user'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class ModalKeyRecommender extends React.Component

  @displayName: 'ModalKeyRecommender'

  @propTypes:
    contacts: React.PropTypes.array.isRequired
    emails: React.PropTypes.array
    callback: React.PropTypes.func

  @defaultProps:
    callback: -> return # NOP

  constructor: (props) ->
    super(props)
    @state = Object.assign({
      currentContact: 0},
      @_getStateFromStores())

  componentDidMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange)

  componentWillUnmount: ->
    @unlistenKeystore()

  _onKeystoreChange: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    identities: PGPKeyStore.pubKeys(@props.emails)

  _selectProfile: (address, identity) =>
    # TODO this is an almost exact duplicate of keybase-search.cjsx:_save
    keybaseUsername = identity.keybase_profile.components.username.val
    identity.addresses.push(address)
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error error
      else
        PGPKeyStore.saveNewKey(identity, key)
    )

  _onNext: =>
    # NOTE: this doesn't do bounds checks! you must do that in render()!
    @setState({currentContact: @state.currentContact + 1})

  _onPrev: =>
    # NOTE: this doesn't do bounds checks! you must do that in render()!
    @setState({currentContact: @state.currentContact - 1})

  _setPage: (page) =>
    # NOTE: this doesn't do bounds checks! you must do that in render()!
    @setState({currentContact: page})
    # indexes from 0 because what kind of monster doesn't

  _onDone: =>
    if @state.identities.length < @props.emails.length
      if !PGPKeyStore._displayDialog(
        'Encrypt without keys for all recipients?',
        'Some recipients are missing PGP public keys. They will not be able to decrypt this message.',
        ['Encrypt', 'Cancel']
      )
        return

    emptyIdents = _.filter(@state.identities, (identity) -> !identity.key?)
    if emptyIdents.length == 0
      Actions.closePopover()
      @props.callback(@state.identities)
    else
      newIdents = []
      for idIndex of emptyIdents
        identity = emptyIdents[idIndex]
        if idIndex < emptyIdents.length - 1
          PGPKeyStore.getKeyContents(key: identity, callback: (identity) => newIdents.push(identity))
        else
          PGPKeyStore.getKeyContents(key: identity, callback: (identity) =>
            newIdents.push(identity)
            @props.callback(newIdents)
            Actions.closePopover()
          )

  _onManageKeys: =>
    Actions.switchPreferencesTab('Encryption')
    Actions.openPreferences()

  render: ->
    # find the email we're dealing with now
    email = @props.emails[@state.currentContact]
    # and a corresponding contact
    contact = _.findWhere(@props.contacts, {'email': email})
    contactString = if contact? then contact.toString() else email
    # find the identity object that goes with this email (if any)
    identity = _.find(@state.identities, (identity) ->
      return email in identity.addresses
    )

    if @state.currentContact == (@props.emails.length - 1)
      # last one
      if @props.emails.length == 1
        # only one
        backButton = false
      else
        backButton = <button className="btn modal-back-button" onClick={ @_onPrev }>Back</button>
      nextButton = <button className="btn modal-next-button" onClick={ @_onDone }>Done</button>
    else if @state.currentContact == 0
      # first one
      backButton = false
      nextButton = <button className="btn modal-next-button" onClick={ @_onNext }>Next</button>
    else
      # somewhere in the middle
      backButton = <button className="btn modal-back-button" onClick={ @_onPrev }>Back</button>
      nextButton = <button className="btn modal-next-button" onClick={ @_onNext }>Next</button>

    if identity?
      deleteButton = (<button title="Delete Public" className="btn btn-toolbar btn-danger" onClick={ => PGPKeyStore.deleteKey(identity) } ref="button">
        Delete Key
      </button>
      )
      body = [
        <div key="title" className="picker-title">This PGP public key has been saved for <br/><b>{ contactString }.</b></div>
        <div className="keybase-profile-solo">
          <KeybaseUser key="keybase-user" profile={ identity }, displayEmailList={false}, actionButton={deleteButton}/>
        </div>
      ]
    else
      if contact?
        query = contact.fullName()
        # don't search Keybase for emails, won't work anyways
        if not query.match(/\s/)?
          query = ""
      else
        query = ""
      importFunc = ((identity) => @_selectProfile(email, identity))

      body = [
        <div key="title" className="picker-title">There is no PGP public key saved for <br/><b>{ contactString }.</b></div>
        <KeybaseSearch key="keybase-search" initialSearch={ query }, importFunc={ importFunc } />
      ]

    prefsButton = <button className="btn modal-prefs-button" onClick={@_onManageKeys}>Advanced Key Management</button>

    <div className="key-picker-modal">
      { body }
      <div style={{flex:1}}></div>
      <div className="picker-controls">
        <div style={{width: 60}}> { backButton } </div>
        { prefsButton }
        <div style={{width: 60}}> { nextButton } </div>
      </div>
    </div>
