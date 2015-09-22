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

Section: Drafts
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
  Public: declare an icon to be displayed in the composer's toolbar (where
  bold, italic, underline, etc are).

  You must declare the following properties:

  - `mutator`: A function that's called when your toolbar button is
  clicked. This mutator function will be passed as its only argument the
  `dom`. The `dom` is the full {DOM} object of the current composer. You
  may mutate this in place. We don't care about the mutator's return
  value.

  - `tooltip`: A one or two word description of what your icon does

  - `iconUrl`: The url of your icon. It should be in the `nylas://` scheme.
  For example: `nylas://your-package-name/assets/my-icon@2x.png`. Note, we
  will downsample your image by 2x (for Retina screens), so make sure it's
  twice the resolution. The icon should be black and white. We will
  directly pass the `url` prop of a {RetinaImg}
  ###
  @composerToolbar: ->
    return

  ###
  Public: Override prepareNewDraft to modify a brand new draft before it is displayed
  in a composer. This is one of the only places in the application where it's safe
  to modify the draft object you're given directly to add participants to the draft,
  add a signature, etc.

  By default, new drafts are considered `pristine`. If the user leaves the composer
  without making any changes, the draft is discarded. If your extension populates
  the draft in a way that makes it "populated" in a valuable way, you should set
  `draft.pristine = false` so the draft saves, even if no further changes are made.
  ###
  @prepareNewDraft: (draft) ->
    return

  ###
  Public: Override finalizeSessionBeforeSending in your DraftStoreExtension subclass to transform
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
  Public: Override onInput in your DraftStoreExtension subclass to
  implement custom behavior as the user types in the composer's
  contenteditable body field.

  As the first argument you are passed the entire DOM object of the
  composer. You may mutate this object and edit it in place.

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
