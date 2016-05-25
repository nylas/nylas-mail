{Utils, React} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseUser = require './keybase-user'
kb = require './keybase'
_ = require 'underscore'

module.exports =
class KeyManager extends React.Component
  @displayName: 'KeyManager'

  @propTypes:
    pubKeys: React.PropTypes.array.isRequired
    privKeys: React.PropTypes.array.isRequired

  constructor: (props) ->
    super(props)

  render: ->
    {pubKeys, privKeys} = @props

    pubKeys = pubKeys.map (identity) =>
      deleteButton = (<button title="Delete Public" className="btn btn-toolbar btn-danger" onClick={ => PGPKeyStore.deleteKey(identity) } ref="button">
        Delete Key
      </button>
      )
      exportButton = (<button title="Export Public" className="btn btn-toolbar" onClick={ => PGPKeyStore.exportKey(identity) } ref="button">
        Export Key
      </button>
      )
      actionButton = (<div className="key-actions">
        {exportButton}
        {deleteButton}
      </div>
      )
      return <KeybaseUser profile={identity} key={identity.clientId} actionButton={actionButton}/>

    privKeys = privKeys.map (identity) =>
      deleteButton = (<button title="Delete Private" className="btn btn-toolbar btn-danger" onClick={ => PGPKeyStore.deleteKey(identity) } ref="button">
        Delete Key
      </button>
      )
      exportButton = (<button title="Export Private" className="btn btn-toolbar" onClick={ => PGPKeyStore.exportKey(identity) } ref="button">
        Export Key
      </button>
      )
      return <KeybaseUser profile={identity} key={identity.clientId} actionButton={deleteButton}/>

    <div className="key-manager">
      <div className="line-w-label">
        <div className="border"></div>
        <div className="title-text">Saved Public Keys</div>
        <div className="border"></div>
      </div>
      <div>
        { pubKeys }
      </div>
      <div className="line-w-label">
        <div className="border"></div>
        <div className="title-text">Saved Private Keys</div>
        <div className="border"></div>
      </div>
      <div>
        { privKeys }
      </div>
    </div>
