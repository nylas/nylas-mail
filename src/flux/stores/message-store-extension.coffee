###
Public: MessageStoreExtension is an abstract base class. To create MessageStoreExtension
that customize message viewing, you should subclass {MessageStoreExtension} and
implement the class methods your plugin needs.

To register your extension with the MessageStore, call {MessageStore::registerExtension}.
When your package is being unloaded, you *must* call the corresponding
{MessageStore::unregisterExtension} to unhook your extension.

```coffee
activate: ->
  MessageStore.registerExtension(MyExtension)

...

deactivate: ->
  MessageStore.unregisterExtension(MyExtension)
```

The MessageStoreExtension API does not currently expose any asynchronous or {Promise}-based APIs.
This will likely change in the future. If you have a use-case for a Message Store extension that
is not possible with the current API, please let us know.

Section: Stores
###
class MessageStoreExtension

  ###
  Public: Transform the message body HTML provided in `body` and return HTML
  that should be displayed for the message.
  ###
  @formatMessageBody: (body) ->
    return body

module.exports = MessageStoreExtension
