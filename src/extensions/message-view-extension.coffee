###
Public: To create MessageViewExtension that customize message viewing, you
should create objects that implement the interface defined at {MessageViewExtension}.

To register your extension with the ExtensionRegistry, call {ExtensionRegistry::MessageView::registerExtension}.
When your package is being unloaded, you *must* call the corresponding
{ExtensionRegistry::MessageView::unregisterExtension} to unhook your extension.

```coffee
activate: ->
  ExtensionRegistry.MessageView.register(MyExtension)

...

deactivate: ->
  ExtensionRegistry.MessageView.unregister(MyExtension)
```

The MessageViewExtension API does not currently expose any asynchronous or {Promise}-based APIs.
This will likely change in the future. If you have a use-case for a Message Store extension that
is not possible with the current API, please let us know.

Section: Extensions
###
class MessageViewExtension

  ###
  Public: Transform the message body HTML provided in `body` and return HTML
  that should be displayed for the message.
  ###
  @formatMessageBody: ({message}) ->
    return body

module.exports = MessageViewExtension
