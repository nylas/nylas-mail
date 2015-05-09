###
Public: DraftStoreExtension is an abstract base class. To create DraftStoreExtensions
that enhance the composer experience, you should subclass {DraftStoreExtension} and
implement the class methods your plugin needs.

To register your extension with the DraftStore, call {DraftStore::registerExtension}.
When your package is being unloaded, you *must* call the corresponding
{DraftStore::unregisterExtension} to unhook your extension.

```coffee
activate: ->
  DraftStore.registerExtension(MyExtension)

...

deactivate: ->
  DraftStore.unregisterExtension(MyExtension)
```

Your DraftStoreExtension subclass should be stateless. The user may have multiple drafts
open at any time, and the methods of your DraftStoreExtension may be called for different
drafts at any time. You should not expect that the session you receive in
 {::finalizeSessionBeforeSending} is for the same draft you previously received in
 {::warningsForSending}, etc.

The DraftStoreExtension API does not currently expose any asynchronous or {Promise}-based APIs.
This will likely change in the future. If you have a use-case for a Draft Store extension that
is not possible with the current API, please let us know.
###
class DraftStoreExtension

  ###
  Public: Inspect the draft, and return any warnings that need to be displayed before
  the draft is sent. Warnings should be string phrases, such as "without an attachment"
  that fit into a message of the form: "Send #{phase1} and #{phase2}?"

  - `draft`: A fully populated {Message} object that is about to be sent.

  Returns a list of warning strings, or an empty array if no warnings need to be displayed.
  ###
  @warningsForSending: (draft) ->
    []

  ###
  Public: Override onMouseUp in your DraftStoreExtension subclass to transform
  the {DraftStoreProxy} editing session just before the draft is sent. This method
  gives you an opportunity to make any final substitutions or changes after any
  {::warningsForSending} have been displayed.

  - `session`: A {DraftStoreProxy} for the draft.

  Example:

  ```coffee
  # Remove any <code> tags found in the draft body
  finalizeSessionBeforeSending: (session) ->
    body = session.draft().body
    clean = body.replace(/<\/?code[^>]*>/g, '')
    if body != clean
      session.changes.add(body: clean)
  ```
  ###
  @finalizeSessionBeforeSending: (session) ->
    return

  ###
  Public: Override onMouseUp in your DraftStoreExtension subclass to
  listen for mouse up events sent to the composer's body text area. This
  hook provides the contenteditable DOM Node itself, allowing you to
  adjust selection ranges and change content as necessary.

  - `editableNode` The composer's contenteditable {Node}
    that received the event.

  - `range`: The currently selected {Range} in the `editableNode`

  - `event`: The mouse up event.
  ###
  @onMouseUp: (editableNode, range, event) ->
    return

  ###
  Public: Called when the user presses `Shift-Tab` while focused on the composer's body field.
  Override onFocusPrevious in your DraftStoreExtension to adjust the selection or perform
  other actions. If your package implements Shift-Tab behavior in a particular scenario, you
  should prevent the default behavior of Shift-Tab via `event.preventDefault()`.

  - `editableNode` The composer's contenteditable {Node} that received the event.

  - `range`: The currently selected {Range} in the `editableNode`

  - `event`: The mouse up event.

  ###
  @onFocusPrevious: (editableNode, range, event) ->
    return


  ###
  Public: Called when the user presses `Tab` while focused on the composer's body field.
  Override onFocusPrevious in your DraftStoreExtension to adjust the selection or perform
  other actions. If your package implements Tab behavior in a particular scenario, you
  should prevent the default behavior of Tab via `event.preventDefault()`.

  - `editableNode` The composer's contenteditable {Node} that received the event.

  - `range`: The currently selected {Range} in the `editableNode`

  - `event`: The mouse up event.

  ###
  @onFocusNext: (editableNode, range, event) ->
    return

  ###
  Public: Override onInput in your DraftStoreExtension subclass to implement
  custom behavior as the user types in the composer's contenteditable body field.

  Example:

  The Nylas `templates` package uses this method to see if the user has populated a
  `<code>` tag placed in the body and change it's CSS class to reflect that it is no
  longer empty.

  ```coffee
  onInput: (editableNode, event) ->
    selection = document.getSelection()

    isWithinNode = (node) ->
      test = selection.baseNode
      while test isnt editableNode
        return true if test is node
        test = test.parentNode
      return false

    codeTags = editableNode.querySelectorAll('code.var.empty')
    for codeTag in codeTags
      if selection.containsNode(codeTag) or isWithinNode(codeTag)
        codeTag.classList.remove('empty')
  ```

  ###
  @onInput: (editableNode, event) ->
    return

module.exports = DraftStoreExtension
