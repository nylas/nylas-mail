ContenteditableExtension = require('./contenteditable-extension')
###
Public: To create ComposerExtensions that enhance the composer experience,
you should create objects that implement the interface defined at
{ComposerExtension}.

{ComposerExtension} extends {ContenteditableExtension}, so you can also
implement the methods defined there to further enhance the composer
experience.

To register your extension with the ExtensionRegistry, call
{ExtensionRegistry::Composer::register}.  When your package is being
unloaded, you *must* call the corresponding
{ExtensionRegistry::Composer::unregister} to unhook your extension.

```
coffee activate: -> ExtensionRegistry.Composer.register(MyExtension)

...

deactivate: -> ExtensionRegistry.Composer.unregister(MyExtension)
```

**Your ComposerExtension should be stateless**. The user may have multiple
drafts open at any time, and the methods of your ComposerExtension may be
called for different drafts at any time. You should not expect that the
session you receive in {::finalizeSessionBeforeSending} is for the same
draft you previously received in {::warningsForSending}, etc.

The ComposerExtension API does not currently expose any asynchronous or
{Promise}-based APIs, except for finalizeSessionBeforeSending. This will likely
change in the future. If you havea use-case for a ComposerExtension that is not possible with the current
API, please let us know.

Section: Extensions
###
class ComposerExtension extends ContenteditableExtension

  ###
  Public: Allows the addition of new types of send actions such as "Send
  Later"

  - `draft`: A fully populated {Message} object that is about to be sent.

  Return an object that adheres to the following spec. If the draft data
  indicates that your action should not be available, then return null.

    - `title`: A short, single string that is displayed to users when
    describing your component. It is used in the hover title text of your
    option in the dropdown menu. It is also used in the "Default Send
    Behavior" dropdown setting. If your string is selected, then the
    `core.sending.defaultSendType` will be set to your string and your
    option will appear as the default.
    ## TODO FIXME: The preferences does not yet know how to dynamically
    # pick these up. For now they are hard-coded.

    - `onSend`: Callback for when your option is clicked as the primary
    action. The function will be passed `{draft}` as its only argument.
    It does not need to return anything. It may be asynchronous and likely
    queue Tasks.

    - `iconUrl`: A custom icon to be placed in the Send button. SendAction
    extensions have the form "Send + {ICON}"
  ###
  @sendActionConfig: ({draft}) ->

  ###
  Public: Inspect the draft, and return any warnings that need to be
  displayed before the draft is sent. Warnings should be string phrases,
  such as "without an attachment" that fit into a message of the form:
  "Send #{phase1} and #{phase2}?"

  - `draft`: A fully populated {Message} object that is about to be sent.

  Returns a list of warning strings, or an empty array if no warnings need
  to be displayed.
  ###
  @warningsForSending: ({draft}) ->
    []

  # ###
  # Public: declare an icon to be displayed in the composer's toolbar (where
  # bold, italic, underline, etc are).
  #
  # You must return an object that contains the following properties:
  #
  # - `mutator`: A function that's called when your toolbar button is
  # clicked. The mutator will be passed: `(contenteditableDOM, selection,
  # event)`.  It will be executed in a wrapped transaction block where it is
  # safe to mutate the DOM and the selection object.
  #
  # - `className`: The button will already have the `btn` and `toolbar-btn`
  # classes.
  #
  # - `tooltip`: A one or two word description of what your icon does
  #
  # - `iconUrl`: The url of your icon. It should be in the `nylas://`
  # scheme.  For example: `nylas://your-package-name/assets/my-icon@2x.png`.
  # Note, we will downsample your image by 2x (for Retina screens), so make
  # sure it's twice the resolution. The icon should be black and white. We
  # will directly pass the `url` prop of a {RetinaImg}
  # ###
  # @composerToolbar: ->
  #   return

  ###
  Public: Override prepareNewDraft to modify a brand new draft before it
  is displayed in a composer. This is one of the only places in the
  application where it's safe to modify the draft object you're given
  directly to add participants to the draft, add a signature, etc.

  By default, new drafts are considered `pristine`. If the user leaves the
  composer without making any changes, the draft is discarded. If your
  extension populates the draft in a way that makes it "populated" in a
  valuable way, you should set `draft.pristine = false` so the draft
  saves, even if no further changes are made.
  ###
  @prepareNewDraft: ({draft}) ->
    return

  ###
  Public: Override finalizeSessionBeforeSending in your ComposerExtension
  subclass to transform the {DraftStoreProxy} editing session just before
  the draft is sent. This method gives you an opportunity to make any
  final substitutions or changes after any {::warningsForSending} have
  been displayed.
  If you want to perform asynchronous work, you this method can return a promise,
  however, returning a Promise is not required.

  - `session`: A {DraftStoreProxy} for the draft.

  Example:

  ```coffee
  # Remove any <code> tags found in the draft body
  finalizeSessionBeforeSending: ({session}) ->
    body = session.draft().body
    clean = body.replace(/<\/?code[^>]*>/g, '')
    if body != clean
      session.changes.add(body: clean)
  ```
  ###
  @finalizeSessionBeforeSending: ({session}) ->
    return Promise.resolve(session)

module.exports = ComposerExtension
