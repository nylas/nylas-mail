NylasStore = require 'nylas-store'
{Actions, FileDownloadStore, DraftStore, MessageBodyProcessor, RegExpUtils} = require 'nylas-exports'
{remote, shell} = require 'electron'
Identity = require './identity'
kb = require './keybase'
pgp = require 'kbpgp'
_ = require 'underscore'
path = require 'path'
fs = require 'fs'
os = require 'os'

class PGPKeyStore extends NylasStore

  constructor: ->
    super()

    @_identities = {}

    @_msgCache = []
    @_msgStatus = []

    # Recursive subdir watching only works on OSX / Windows. annoying
    @_pubWatcher = null
    @_privWatcher = null

    @_keyDir = path.join(NylasEnv.getConfigDirPath(), 'keys')
    @_pubKeyDir = path.join(@_keyDir, 'public')
    @_privKeyDir = path.join(@_keyDir, 'private')

    # Create the key storage file system if it doesn't already exist
    fs.access(@_keyDir, fs.R_OK | fs.W_OK, (err) =>
      if err
        fs.mkdir(@_keyDir, (err) =>
          if err
            console.warn err
          else
            fs.mkdir(@_pubKeyDir, (err) =>
              if err
                console.warn err
              else
                fs.mkdir(@_privKeyDir, (err) =>
                  if err
                    console.warn err
                  else
                    @watch())))
      else
        fs.access(@_pubKeyDir, fs.R_OK | fs.W_OK, (err) =>
          if err
            fs.mkdir(@_pubKeyDir, (err) =>
              if err
                console.warn err))
        fs.access(@_privKeyDir, fs.R_OK | fs.W_OK, (err) =>
          if err
            fs.mkdir(@_privKeyDir, (err) =>
              if err
                console.warn err))
        @_populate()
        @watch())

  validAddress: (address, isPub) =>
    if (!address || address.length == 0)
      @_displayError('You must provide an email address.')
      return false
    if not (RegExpUtils.emailRegex().test(address))
      @_displayError('Invalid email address.')
      return false
    keys = if isPub then @pubKeys(address) else @privKeys({address: address, timed: false})
    keystate = if isPub then 'public' else 'private'
    if (keys.length > 0)
      @_displayError("A PGP #{keystate} key for that email address already exists.")
      return false
    return true

  ### I/O and File Tracking ###

  watch: =>
    if (!@_pubWatcher)
      @_pubWatcher = fs.watch(@_pubKeyDir, @_populate)
    if (!@_privWatcher)
      @_privWatcher = fs.watch(@_privKeyDir, @_populate)

  unwatch: =>
    if (@_pubWatcher)
      @_pubWatcher.close()
    @_pubWatcher = null
    if (@_privWatcher)
      @_privWatcher.close()
    @_privWatcher = null

  _populate: =>
    # add identity elements to later be populated with keys from disk
    # TODO if this function is called multiple times in quick succession it
    # will duplicate keys - need to do deduplication on add
    fs.readdir(@_pubKeyDir, (err, pubFilenames) =>
      fs.readdir(@_privKeyDir, (err, privFilenames) =>
        @_identities = {}
        _.each([[pubFilenames, false], [privFilenames, true]], (readresults) =>
          filenames = readresults[0]
          i = 0
          if filenames.length == 0
            @trigger(@)
          while i < filenames.length
            filename = filenames[i]
            if filename[0] == '.'
              continue
            ident = new Identity({
              addresses: filename.split(" ")
              isPriv: readresults[1]
            })
            @_identities[ident.clientId] = ident
            @trigger(@)
            i++)
      )
    )

  getKeyContents: ({key, passphrase, callback}) =>
    # Reads an actual PGP key from disk and adds it to the preexisting metadata
    if not key.keyPath?
      console.error "Identity has no path for key!", key
      return
    fs.readFile(key.keyPath, (err, data) =>
      pgp.KeyManager.import_from_armored_pgp {
        armored: data
      }, (err, km) =>
        if err
          console.warn err
        else
          if km.is_pgp_locked()
            # private key - check passphrase
            passphrase ?= ""
            km.unlock_pgp { passphrase: passphrase }, (err) =>
              if err
                # decrypt checks all keys, so DON'T open an error dialog
                console.warn err
                return
              else
                key.key = km
                key.setTimeout()
                if callback?
                  callback(key)
          else
            # public key - get keybase data
            key.key = km
            key.setTimeout()
            @getKeybaseData(key)
            if callback?
              callback(key)
        @trigger(@)
    )

  getKeybaseData: (identity) =>
    # Given a key, fetches metadata from keybase about that key
    # TODO currently only works for public keys
    if not identity.key? and not identity.isPriv and not identity.keybase_profile
      @getKeyContents(key: identity)
    else
      fingerprint = identity.fingerprint()
      if fingerprint?
        kb.getUser(fingerprint, 'key_fingerprint', (err, user) =>
          if err
            console.error(err)
          if user?.length == 1
            identity.keybase_profile = user[0]
          @trigger(@)
        )

  saveNewKey: (identity, contents) =>
    # Validate the email address(es), then write to file.
    if not identity instanceof Identity
      console.error "saveNewKey requires an identity object"
      return
    addresses = identity.addresses
    if addresses.length < 1
      console.error "Identity must have at least one email address to save key"
      return
    if _.every(addresses, (address) => @validAddress(address, !identity.isPriv))
      # Just say no to trailing whitespace.
      if contents.charAt(contents.length - 1) != '-'
        contents = contents.slice(0, -1)
      fs.writeFile(identity.keyPath, contents, (err) =>
        if (err)
          @_displayError(err)
      )

  exportKey: ({identity, passphrase}) =>
    atIndex = identity.addresses[0].indexOf("@")
    suffix = if identity.isPriv then "-private.asc" else ".asc"
    shortName = identity.addresses[0].slice(0, atIndex).concat(suffix)
    NylasEnv.savedState.lastKeybaseDownloadDirectory ?= os.homedir()
    savePath = path.join(NylasEnv.savedState.lastKeybaseDownloadDirectory, shortName)
    @getKeyContents(key: identity, passphrase: passphrase, callback: ( (identity) =>
      NylasEnv.showSaveDialog({
        title: "Export PGP Key",
        defaultPath: savePath,
      }, (keyPath) =>
        if (!keyPath)
          return
        NylasEnv.savedState.lastKeybaseDownloadDirectory = keyPath.slice(0, keyPath.length - shortName.length)
        if passphrase?
          identity.key.export_pgp_private {passphrase: passphrase}, (err, pgp_private) =>
            if (err)
              @_displayError(err)
            fs.writeFile(keyPath, pgp_private, (err) =>
              if (err)
                @_displayError(err)
              shell.showItemInFolder(keyPath)
            )
        else
          identity.key.export_pgp_public {}, (err, pgp_public) =>
            fs.writeFile(keyPath, pgp_public, (err) =>
              if (err)
                @_displayError(err)
              shell.showItemInFolder(keyPath)
            )
      )
    )
    )

  deleteKey: (key) =>
    if this._displayDialog(
      'Delete this key?',
      'The key will be permanently deleted.',
      ['Delete', 'Cancel']
    )
      fs.unlink(key.keyPath, (err) =>
        if (err)
          @_displayError(err)
        @_populate()
      )

  addAddressToKey: (profile, address) =>
    if @validAddress(address, !profile.isPriv)
      oldPath = profile.keyPath
      profile.addresses.push(address)
      fs.rename(oldPath, profile.keyPath, (err) =>
        if (err)
          @_displayError(err)
        )

  removeAddressFromKey: (profile, address) =>
    if profile.addresses.length > 1
      oldPath = profile.keyPath
      profile.addresses = _.without(profile.addresses, address)
      fs.rename(oldPath, profile.keyPath, (err) =>
        if (err)
          @_displayError(err)
        )
    else
      @deleteKey(profile)

  ### Internal Key Management ###

  pubKeys: (addresses) =>
    # fetch public identity/ies for an address (synchronous)
    # if no address, return them all
    identities = _.where(_.values(@_identities), {isPriv: false})

    if not addresses?
      return identities

    if typeof addresses is "string"
      addresses = [addresses]

    identities = _.filter(identities, (identity) ->
      return _.intersection(addresses, identity.addresses).length > 0
    )
    return identities

  privKeys: ({address, timed} = {timed: true}) =>
    # fetch private identity/ies for an address (synchronous).
    # by default, only return non-timed-out keys
    # if no address, return them all
    identities = _.where(_.values(@_identities), {isPriv: true})

    if address?
      identities = _.filter(identities, (identity) ->
        return address in identity.addresses
      )

    if timed
      identities = _.reject(identities, (identity) ->
        return identity.isTimedOut()
      )

    return identities

  _displayError: (err) ->
    dialog = remote.dialog
    dialog.showErrorBox('Key Management Error', err.toString())

  _displayDialog: (title, message, buttons) ->
    dialog = remote.dialog
    return (dialog.showMessageBox({
      title: title,
      message: title,
      detail: message,
      buttons: buttons,
      type: 'info',
    }) == 0)

  msgStatus: (msg) ->
    # fetch the latest status of a message
    if not msg?
      return null
    else
      clientId = msg.clientId
      statuses = _.filter @_msgStatus, (status) ->
        return status.clientId == clientId
      status = _.max statuses, (stat) ->
        return stat.time
    return status.message

  isDecrypted: (message) ->
    # if the message is already decrypted, return true
    # if the message has no encrypted component, return true
    # if the message has an encrypted component that is not yet decrypted, return false
    if not @hasEncryptedComponent(message)
      return true
    else if @getDecrypted(message)?
      return true
    else
      return false

  getDecrypted: (message) =>
    # Fetch a cached decrypted message
    # (synchronous)

    if message.clientId in _.pluck(@_msgCache, 'clientId')
      msg = _.findWhere(@_msgCache, {clientId: message.clientId})
      if msg.timeout > Date.now()
        return msg.body

    # otherwise
    return null

  hasEncryptedComponent: (message) ->
    if not message.body?
      return false

    # find a PGP block
    pgpStart = "-----BEGIN PGP MESSAGE-----"
    pgpEnd = "-----END PGP MESSAGE-----"

    blockStart = message.body.indexOf(pgpStart)
    blockEnd = message.body.indexOf(pgpEnd)
    # if they're both present, assume an encrypted block
    return (blockStart >= 0 and blockEnd >= 0)

  fetchEncryptedAttachments: (message) ->
    encrypted = _.map(message.files, (file) =>
      # calendars don't have filenames
      if file.filename?
        tokenized = file.filename.split('.')
        extension = tokenized[tokenized.length - 1]
        if extension == "asc" or extension == "pgp"
          # something.asc or something.pgp -> assume encrypted attachment
          return file
        else
          return null
      else
        return null
      )
    # NOTE for now we don't verify that the .asc/.pgp files actually have a PGP
    # block inside

    return _.compact(encrypted)

  decrypt: (message) =>
    # decrypt a message, cache the result
    # (asynchronous)

    # check to make sure we haven't already decrypted and cached the message
    # note: could be a race condition here causing us to decrypt multiple times
    # (not that that's a big deal other than minor resource wastage)
    if @getDecrypted(message)?
      return

    if not @hasEncryptedComponent(message)
      return

    # fill our keyring with all possible private keys
    ring = new pgp.keyring.KeyRing
    # (the unbox function will use the right one)

    for key in @privKeys({timed: true})
      if key.key?
        ring.add_key_manager(key.key)

    # find a PGP block
    pgpStart = "-----BEGIN PGP MESSAGE-----"
    blockStart = message.body.indexOf(pgpStart)

    pgpEnd = "-----END PGP MESSAGE-----"
    blockEnd = message.body.indexOf(pgpEnd) + pgpEnd.length

    # if we don't find those, it isn't encrypted
    return unless (blockStart >= 0 and blockEnd >= 0)

    pgpMsg = message.body.slice(blockStart, blockEnd)

    # Some users may send messages from sources that pollute the encrypted block.
    pgpMsg = pgpMsg.replace(/&#43;/gm,'+')
    pgpMsg = pgpMsg.replace(/(<br>)/g, '\n')
    pgpMsg = pgpMsg.replace(/<\/(blockquote|div|dl|dt|dd|form|h1|h2|h3|h4|h5|h6|hr|ol|p|pre|table|tr|td|ul|li|section|header|footer)>/g, '\n')
    pgpMsg = pgpMsg.replace(/<(.+?)>/g, '')
    pgpMsg = pgpMsg.replace(/&nbsp;/g, ' ')

    pgp.unbox { keyfetch: ring, armored: pgpMsg }, (err, literals, warnings, subkey) =>
      if err
        console.warn err
        errMsg = "Unable to decrypt message."
        if err.toString().indexOf("tailer found") >= 0 or err.toString().indexOf("checksum mismatch") >= 0
          errMsg = "Unable to decrypt message. Encrypted block is malformed."
        else if err.toString().indexOf("key not found:") >= 0
          errMsg = "Unable to decrypt message. Private key does not match encrypted block."
          if !@msgStatus(message)?
            errMsg = "Decryption preprocessing failed."
        Actions.recordUserEvent("Email Decryption Errored", {error: errMsg})
        @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": errMsg})
      else
        if warnings._w.length > 0
          console.warn warnings._w

        if literals.length > 0
          plaintext = literals[0].toString('utf8')

          # <pre> tag for consistent styling
          if plaintext.indexOf("<pre>") == -1
            plaintext = "<pre>\n" + plaintext + "\n</pre>"

          # can't use _.template :(
          body = message.body.slice(0, blockStart) + plaintext + message.body.slice(blockEnd)

          # TODO if message is already in the cache, consider updating its TTL
          timeout = 1000 * 60 * 30 # 30 minutes in ms
          @_msgCache.push({clientId: message.clientId, body: body, timeout: Date.now() + timeout})
          keyprint = subkey.get_fingerprint().toString('hex')
          @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": "Message decrypted with key #{keyprint}"})
          # re-render messages
          Actions.recordUserEvent("Email Decrypted")
          MessageBodyProcessor.resetCache()
          @trigger(@)
        else
          console.warn "Unable to decrypt message."
          @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": "Unable to decrypt message."})

  decryptAttachments: (identity, files) =>
    # fill our keyring with all possible private keys
    keyring = new pgp.keyring.KeyRing
    # (the unbox function will use the right one)

    if identity.key?
      keyring.add_key_manager(identity.key)

    FileDownloadStore._fetchAndSaveAll(files).then((filepaths) ->
      # open, decrypt, and resave each of the newly-downloaded files in place
      _.each(filepaths, (filepath) =>
        fs.readFile(filepath, (err, data) =>
          # find a PGP block
          pgpStart = "-----BEGIN PGP MESSAGE-----"
          blockStart = data.indexOf(pgpStart)

          pgpEnd = "-----END PGP MESSAGE-----"
          blockEnd = data.indexOf(pgpEnd) + pgpEnd.length

          # if we don't find those, it isn't encrypted
          return unless (blockStart >= 0 and blockEnd >= 0)

          pgpMsg = data.slice(blockStart, blockEnd)

          # decrypt the file
          pgp.unbox({ keyfetch: keyring, armored: pgpMsg }, (err, literals, warnings, subkey) =>
            if err
              console.warn err
            else
              if warnings._w.length > 0
                console.warn warnings._w

            literalLen = literals?.length
            # if we have no literals, failed to decrypt and should abort
            return unless literalLen?

            if literalLen == 1
              # success! replace old encrypted file with awesome decrypted file
              filepath = filepath.slice(0, filepath.length-3).concat("txt")
              fs.writeFile(filepath, literals[0].toBuffer(), (err) =>
                if err
                  console.warn err
              )
            else
              console.warn "Attempt to decrypt attachment failed: #{literalLen} literals found, expected 1."
          )
        )
      )
    )


module.exports = new PGPKeyStore()
