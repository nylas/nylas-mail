{Utils, React} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseUser = require './keybase-user'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class KeyManager extends React.Component
  @displayName: 'KeyManager'

  @propTypes:
    keys: React.PropTypes.array.isRequired

  constructor: (props) ->
    super(props)

  _matchKeys: (targetIdentity, keys) =>
    # given a single key to match, and an array of keys to match from, returns
    # a key from the array with the same fingerprint as the target key, or null
    if not targetIdentity.key?
      return null

    key = _.find(keys, (key) =>
      return key.key? and key.fingerprint() == targetIdentity.fingerprint()
    )

    if key == undefined
      return null
    else
      return key

  _delete: (email, identity) =>
    # delete a locally saved key
    keys = PGPKeyStore.pubKeys(email)
    key = @_matchKeys(identity, keys)
    if key?
      PGPKeyStore.deleteKey(key)
    else
      console.error "Unable to fetch key for #{email}"
      NylasEnv.showErrorDialog("Unable to fetch key for #{email}.")

  render: ->
    {keys} = @props

    keys = keys.map (identity) =>
      deleteButton = (<button title="Delete" className="btn btn-toolbar btn-danger" onClick={ => @_delete(identity.addresses[0], identity) } ref="button">
        Delete Key
      </button>
      )
      return <KeybaseUser profile={identity} key={identity.clientId} actionButton={ deleteButton }/>

    if keys.length < 1
      #keys = (<span>No keys saved!</span>)
      keys = false

    <div className="key-manager">
      { keys }
    </div>
