{ComponentRegistry, ExtensionRegistry} = require 'nylas-exports'
{activate, deactivate} = require '../lib/main'

EncryptMessageButton = require '../lib/encrypt-button'
DecryptMessageButton = require '../lib/decrypt-button'
DecryptPGPExtension = require '../lib/decryption-preprocess'

describe "activate", ->
  it "should register the encryption button", ->
    spyOn(ComponentRegistry, 'register')
    activate()
    expect(ComponentRegistry.register).toHaveBeenCalledWith(EncryptMessageButton, {role: 'Composer:ActionButton'})

  it "should register the decryption button", ->
    spyOn(ComponentRegistry, 'register')
    activate()
    expect(ComponentRegistry.register).toHaveBeenCalledWith(DecryptMessageButton, {role: 'message:BodyHeader'})

  it "should register the decryption processor", ->
    spyOn(ExtensionRegistry.MessageView, 'register')
    activate()
    expect(ExtensionRegistry.MessageView.register).toHaveBeenCalledWith(DecryptPGPExtension)


describe "deactivate", ->
  it "should unregister the encrypt button", ->
    spyOn(ComponentRegistry, 'unregister')
    deactivate()
    expect(ComponentRegistry.unregister).toHaveBeenCalledWith(EncryptMessageButton)

  it "should unregister the decryption button", ->
    spyOn(ComponentRegistry, 'unregister')
    deactivate()
    expect(ComponentRegistry.unregister).toHaveBeenCalledWith(DecryptMessageButton)

  it "should unregister the decryption processor", ->
    spyOn(ExtensionRegistry.MessageView, 'unregister')
    deactivate()
    expect(ExtensionRegistry.MessageView.unregister).toHaveBeenCalledWith(DecryptPGPExtension)
