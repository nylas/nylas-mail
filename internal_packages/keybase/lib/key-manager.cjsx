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

  render: ->
    {keys} = @props

    keys = keys.map (key) =>
      if key.key?
        uid = "key-manager-" + key.key.get_pgp_fingerprint().toString('hex')
      else if key.keybase_user?
        uid = "key-manager-" + key.keybase_user.components.username.val
      else
        uid = "key-manager-" + key.addresses.join('')
      return <KeybaseUser profile={key} key={uid} />

    if keys.length < 1
      keys = (<span>No keys saved!</span>)

    <div className="key-manager">
      { keys }
    </div>
