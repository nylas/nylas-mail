{Utils, React, Actions} = require 'nylas-exports'
PGPKeyStore = require './pgp-key-store'
KeybaseUser = require './keybase-user'
PassphrasePopover = require './passphrase-popover'
kb = require './keybase'
_ = require 'underscore'
pgp = require 'kbpgp'
fs = require 'fs'

module.exports =
class KeyManager extends React.Component
  @displayName: 'KeyManager'

  @propTypes:
    pubKeys: React.PropTypes.array.isRequired
    privKeys: React.PropTypes.array.isRequired

  constructor: (props) ->
    super(props)

  _exportPopoverDone: (passphrase, identity) =>
    # check the passphrase before opening the save dialog
    fs.readFile(identity.keyPath, (err, data) =>
      pgp.KeyManager.import_from_armored_pgp {
        armored: data
      }, (err, km) =>
        if err
          console.warn err
        else
          km.unlock_pgp { passphrase: passphrase }, (err) =>
            if err
              PGPKeyStore._displayError(err)
            else
              PGPKeyStore.exportKey({identity: identity, passphrase: passphrase})
    )

  _exportPrivateKey: (identity, event) =>
    popoverTarget = event.target.getBoundingClientRect()

    Actions.openPopover(
      <PassphrasePopover identity={identity} addresses={identity.addresses} onPopoverDone={ @_exportPopoverDone } />,
      {originRect: popoverTarget, direction: 'left'}
    )

  render: ->
    {pubKeys, privKeys} = @props

    pubKeys = pubKeys.map (identity) =>
      deleteButton = (<button title="Delete Public" className="btn btn-toolbar btn-danger" onClick={ => PGPKeyStore.deleteKey(identity) } ref="button">
        Delete Key
      </button>
      )
      exportButton = (<button title="Export Public" className="btn btn-toolbar" onClick={ => PGPKeyStore.exportKey({identity: identity}) } ref="button">
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
      exportButton = (<button title="Export Private" className="btn btn-toolbar" onClick={ (event) => @_exportPrivateKey(identity, event) } ref="button">
        Export Key
      </button>
      )
      actionButton = (<div className="key-actions">
        {exportButton}
        {deleteButton}
      </div>
      )
      return <KeybaseUser profile={identity} key={identity.clientId} actionButton={actionButton}/>

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
