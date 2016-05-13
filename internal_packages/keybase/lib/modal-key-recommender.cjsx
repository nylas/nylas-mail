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
    callback: React.PropTypes.function

  @defaultProps:
    callback: () -> return # NOP

  constructor: (props) ->
    super(props)
    @state = Object.assign({
      currentContact: 0},
      @_getStateFromStores())

  componentDidMount: ->
    @unlistenKeystore = PGPKeyStore.listen(@_onKeystoreChange)

  componentWillUnmount: ->
    @unlistenKeystore()

  _onKeystoreChange: () =>
    @setState(@_getStateFromStores())

  _getStateFromStores: () =>
    identities: PGPKeyStore.pubKeys(_.pluck(@props.contacts, 'email'))

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
    Actions.closePopover()
    @props.callback()

  render: ->
    # dedupe the contacts, since we deal with addresses and not contacts
    uniqEmails = _.uniq(_.pluck(@props.contacts, 'email'))
    # find the email we're dealing with now
    email = uniqEmails[@state.currentContact]
    # and a corresponding contact
    contact = _.findWhere(@props.contacts, {'email': email})
    # find the identity object that goes with this email (if any)
    identity = _.find(@state.identities, (identity) ->
      return email in identity.addresses
    )

    if @state.currentContact == (uniqEmails.length - 1)
      # last one
      backButton = <button onClick={ @_onPrev }>Back</button>
      nextButton = <button onClick={ @_onDone }>Looks good!</button>
    else if @state.currentContact == 0
      # first one
      backButton = false
      nextButton = <button onClick={ @_onNext }>Next</button>
    else
      # somewhere in the middle
      backButton = <button onClick={ @_onPrev }>Back</button>
      nextButton = <button onClick={ @_onNext }>Next</button>

    pages = uniqEmails.map((email, index) =>
      # TODO indicate if a key is loaded for each of the pages
      return <span onClick={ => @_setPage(index) }>({ index })</span>
      # TODO buttons here instead of terrible text
    )

    if identity?
      body = <KeybaseUser profile={ identity } />
    else
      query = contact.fullName()
      importFunc = ((identity) => @_selectProfile(email, identity))

      body = [
        <div key="title" className="picker-title">Associate a key for: <b>{ contact.toString() }</b></div>
        <KeybaseSearch key="keybase-search" initialSearch={ query }, importFunc={ importFunc } />
      ]

    <div className="key-picker-modal">
      { body }
      <div style={flex: 1}></div>
      <div className="picker-controls">{ backButton } { pages } { nextButton }</div>
    </div>
