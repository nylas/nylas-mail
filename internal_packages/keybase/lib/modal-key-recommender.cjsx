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

  constructor: (props) ->
    super(props)
    @state = Object.assign({
      currentContact: props.contacts[0]},
      @_getStateFromStores())

  componentWillMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange)

  componentWillUnmount: ->
    @unlistenKeystore()

  _onKeystoreChange: () =>
    @setState(@_getStateFromStores)

  _getStateFromStores: () =>
    identities: PGPKeyStore.pubKeys(_.pluck(@props.contacts, 'email'))

  _selectProfile: (address, identity) =>
    keybaseUsername = identity.keybase_profile.components.username.val
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error "Unable to fetch key for #{keybaseUsername}"
      else
        PGPKeyStore.saveNewKey(address, key, true) # isPub = true
    )


  render: ->
    contact = @state.currentContact
    contactIdentity = _.find(@state.identities, (identity) ->
      return contact.email in identity.addresses
    )

    if contactIdentity?
      <KeybaseUser profile={ contactIdentity[0] } />
    else
      query = contact.fullName()

      # TODO each KeybaseUser should have:
      # onClick={ => @_selectProfile(contact.email, contactIdentity[0]) }
      <div>
        <div>Associate a key for: <b>{ contact.toString() }</b></div>

        <KeybaseSearch initialSearch={ query } />

        <button onClick={ => Actions.closeModal() }>Skip</button>
      </div>
