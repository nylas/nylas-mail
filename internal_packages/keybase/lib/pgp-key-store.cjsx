NylasStore = require 'nylas-store'
{DraftStore, MessageBodyProcessor, RegExpUtils} = require 'nylas-exports'
{remote} = require 'electron'
kb = require './keybase'
pgp = require 'kbpgp'
_ = require 'underscore'
path = require 'path'
fs = require 'fs'

class PGPKeyStore extends NylasStore

  constructor: ->
    super()

    @_pubKeys = []
    @_privKeys = []

    @_msgCache = []
    @_msgStatus = []

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
        @_populate(isPub = true)
        @_populate(isPub = false)
        @watch())

    @unlisten = DraftStore.listen(@_onDraftChanged, @)

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
      @_pubWatcher = fs.watch(@_pubKeyDir, => @_populate(isPub = true))
    if (!@_privWatcher)
      @_privWatcher = fs.watch(@_privKeyDir, => @_populate(isPub = false))

  unwatch: =>
    if (@_pubWatcher)
      @_pubWatcher.close()
    @_pubWatcher = null
    if (@_privWatcher)
      @_privWatcher.close()
    @_privWatcher = null

  _populate: (isPub) =>
    # add metadata elements (sans keys) to later be populated with actual keys
    # from disk
    if isPub
      keyDirectory = @_pubKeyDir
      @_pubKeys = []
    else
      keyDirectory = @_privKeyDir
      @_privKeys = []
    fs.readdir(keyDirectory, (err, filenames) =>
      i = 0
      if filenames.length == 0
        @trigger(@)
      else
        while i < filenames.length
          filename = filenames[i]
          if filename[0] == '.'
            continue
          absname = path.join(keyDirectory, filename)
          key = {
            path: absname,
            addresses: filename.split(" ")
          }
          if isPub
            @_pubKeys.push(key)
          else
            @_privKeys.push(key)
          @trigger(@)
          i++)

  getKeyContents: ({key, passphrase}) =>
    # Reads an actual PGP key from disk and adds it to the preexisting metadata
    fs.readFile(key.path, (err, data) =>
      pgp.KeyManager.import_from_armored_pgp {
        armored: data
      }, (err, km) =>
        if err
          console.warn err
        else
          if km.is_pgp_locked()
            if passphrase?
              km.unlock_pgp { passphrase: passphrase }, (err) =>
                if err
                  console.warn err
            else
              console.error "No passphrase provided, but key is private."
          timeout = 1000 * 60 * 30 # 30 minutes in ms
          # NOTE this only allows for one priv key per address
          # if it's already there, update, else insert
          key.key = km
          key.timeout = Date.now() + timeout
          @getKeybaseData(key)
        @trigger(@)
    )

  getKeybaseData: (key) =>
    # Given a key, fetches metadata from keybase about that key
    if not key.key?
      @getKeyContents(key: key)
    else
      fingerprint = key.key.get_pgp_fingerprint().toString('hex')
      kb.getUser(fingerprint, 'key_fingerprint', (err, user) =>
        if user?.length == 1
          key.keybase_user = user[0]
          @trigger(@)
      )

  saveNewKey: (address, contents, isPub) =>
    # Validate the email address, then write to file.
    if @validAddress(address, isPub)
      if isPub
        keyPath = path.join(@_pubKeyDir, address)
      else
        keyPath = path.join(@_privKeyDir, address)
      # Just say no to trailing whitespace.
      if contents.charAt(contents.length - 1) != '-'
        contents = contents.slice(0, -1)
      fs.writeFile(keyPath, contents, (err) =>
        if (err)
          @_displayError(err)
      )

  deleteKey: (key) =>
    if this._displayDialog(
      'Delete this key?',
      'The key will be permanently deleted.',
      ['Delete', 'Cancel']
    )
      fs.unlink(key.path, (err) =>
        if (err)
          @_displayError(err)
      )

  addAddressToKey: (profile, address) =>
    # NOTE: this is ONLY for public keys
    if @validAddress(address, true)
      profile.addresses.push(address)
      newPath = path.join(@_pubKeyDir, profile.addresses.join(" "))
      fs.rename(profile.path, newPath, (err) =>
        if (err)
          @_displayError(err)
        )

  removeAddressFromKey: (profile, address) =>
    # NOTE: this is ONLY for public keys
    if profile.addresses.length > 1
      profile.addresses = _.without(profile.addresses, address)
      newPath = path.join(@_pubKeyDir, profile.addresses.join(" "))
      fs.rename(profile.path, newPath, (err) =>
        if (err)
          @_displayError(err)
        )
    else
      @deleteKey(profile)

  ### Internal Key Management ###

  pubKeys: (address) =>
    # TODO allow passing list of addresses
    # fetch public key(s) for an address (synchronous)
    # if no address, return them all
    keys = []
    if not address?
      keys = @_pubKeys
    else
      keys = _.filter @_pubKeys, (key) ->
        return address in key.addresses
    keys

  privKeys: ({address, timed}) =>
    # fetch private key(s) for an address (synchronous).
    # by default, only return non-timed-out keys
    # if no address, return them all
    keys = []
    if not address?
      if timed
        keys = _.filter @_privKeys, (key) ->
          return key.timeout > Date.now()
      else
        keys = @_privKeys
    else
      address_keys = _.filter @_privKeys, (key) ->
        return address in key.addresses
      if timed
        keys = _.filter address_keys, (key) ->
          key.timeout > Date.now()
      else
        keys = address_keys
    return keys

  _displayError: (message) ->
    dialog = remote.require('dialog')
    dialog.showErrorBox('Key Management Error', message)

  _displayDialog: (title, message, buttons) ->
    dialog = remote.require('dialog')
    return (dialog.showMessageBox({
      title: title,
      message: title,
      detail: message,
      buttons: buttons,
      type: 'info',
    }) == 0)

  msgStatus: (msg) ->
    # fetch the latest status of a message
    # (synchronous)

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
    # if the message has an encrypted component that is not yet decrypted,
    # return false
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

    for key in @privKeys({timed:false})
      if key.key?
        ring.add_key_manager(key.key)

    # find a PGP block
    pgpStart = "-----BEGIN PGP MESSAGE-----"
    blockStart = message.body.indexOf(pgpStart)

    pgpEnd = "-----END PGP MESSAGE-----"
    blockEnd = message.body.indexOf(pgpEnd) + pgpEnd.length

    pgpMsg = message.body.slice(blockStart, blockEnd)

    # There seemed to be a problem where '+' was being encoded, and there are
    # some potential issues with HTML tags being added to the message
    # pgpMsg = pgpMsg.replace(/&#43;/gm,'+')
    # pgpMsg = pgpMsg.replace(/<[^>]*>/gm,'')
    # however, it appears the problem has disappeared

    # TODO pgp.unbox fails on generated keys with "no tailer found". I have no idea why.
    # Previously this was caused by a trailing whitespace issue but that doesn't appear
    # to be the problem here. Googling the error turns up two Github issues, both about
    # the difference between single and triple quoted string literals in CoffeeScript -
    # maybe that's a place to start?
    #console.warn(@privKeys({})[0].key.armored_pgp_public)
    pgp.unbox { keyfetch: ring, armored: pgpMsg }, (err, literals, warnings, subkey) =>
      if err
        console.warn err
        @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": "Unable to decrypt message."})
      else
        if warnings._w.length > 0
          console.warn warnings._w

        if literals.length > 0
          plaintext = literals[0].toString('utf8')
          pre = """
                <style>
                  div.decrypted {
                    border: 3px solid rgb(121, 212, 91);
                    border-radius: 4px;
                    padding: 8px 12px;
                    box-sizing: border-box;
                  }
                </style>
                <div class="decrypted">
                """

          post = """
                 </div>
                 """
          # can't use _.template :(
          body = message.body.slice(0, blockStart) + pre + plaintext + post + message.body.slice(blockEnd)

          # TODO if message is already in the cache, consider updating its TTL
          timeout = 1000 * 60 * 30 # 30 minutes in ms
          @_msgCache.push({clientId: message.clientId, body: body, timeout: Date.now() + timeout})
          keyprint = subkey.get_fingerprint().toString('hex')
          @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": "Message decrypted with key #{keyprint}!"})
          # re-render messages
          MessageBodyProcessor.resetCache()
          @trigger(@)
        else
          console.warn "Unable to decrypt message."
          @_msgStatus.push({"clientId": message.clientId, "time": Date.now(), "message": "Unable to decrypt message."})

  _onDraftChanged: (changes) ->
    # every time the draft changes, get keys for all the recipients
    if !changes
      return
    for draft in changes.objects
      for recipient in draft.to
        recipientKeys = @pubKeys(recipient.email)
        for recipientKey in recipientKeys
          if 'key' not of recipientKey
            @getKeyContents(key: recipientKey)

module.exports = new PGPKeyStore()
