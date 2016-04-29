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
    # TODO this is an almost exact duplicate of keybase-search.cjsx:_save
    keybaseUsername = identity.keybase_profile.components.username.val
    kb.getKey(keybaseUsername, (error, key) =>
      if error
        console.error error
      else
        PGPKeyStore.saveNewKey(address, key, true) # isPub = true
    )


  render: ->
    contact = @state.currentContact
    contactIdentity = _.find(@state.identities, (identity) ->
      return contact.email in identity.addresses
    )

    if contactIdentity?
      console.log contactIdentity
      <div>
        <KeybaseUser profile={ contactIdentity } />

        <button onClick={ => Actions.closeModal() }>Looks good!</button>
      </div>
    else
      query = contact.fullName()
      importFunc = ((identity) => @_selectProfile(contact.email, identity))

      <div>
        <div>Associate a key for: <b>{ contact.toString() }</b></div>

        <KeybaseSearch initialSearch={ query }, importFunc={ importFunc } />

        <button onClick={ => Actions.closeModal() }>Skip adding key</button>
      </div>
