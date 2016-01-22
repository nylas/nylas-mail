###
Public: ContenteditableExtension is an abstract base class.
Implementations of this are used to make additional changes to a
<Contenteditable /> component beyond a user's input intents. The hooks in
this class provide the contenteditable DOM Node itself, allowing you to
adjust selection ranges and change content as necessary.

While some ContenteditableExtension are included with the core
<{Contenteditable} /> component, others may be added via the `plugins`
prop when you use it inside your own components.

Example:

```javascript
render() {
  return(
    <div>
      <Contenteditable extensions={[MyAwesomeExtension]}>
    </div>
  );
}
```

If you specifically want to enhance the Composer experience you should
register a {ComposerExtension}

Section: Extensions
###
class ContenteditableExtension

  ###
  Public: Gets called anytime any atomic change is made to the DOM of the
  contenteditable.

  When a user types a key, deletes some text, or does anything that
  changes the DOM. it will trigger `onContentChanged`. It is wrapper over
  a native DOM {MutationObserver}. It only gets called if there are
  mutations

  This also gets called at the end of callbacks that mutate the DOM. If
  another extension overrides `onClick` and performs several mutations to
  the DOM during that callback, those changes will be batched and then
  `onContentChanged` will be called once at the end of the callback with
  those mutations.

  Callback params:
    - editor: The {Editor} controller that provides a host of convenience
    methods for manipulating the selection and DOM
    - mutations: An array of DOM Mutations as returned by the
    {MutationObserver}. Note that these may not always be populated

  You may mutate the contenteditable in place, we do not expect any return
  value from this method.

  The onContentChanged event can be triggered by a variety of events, some
  of which could have been already been looked at by a callback. Any DOM
  mutation will fire this event. Sometimes those mutations are the cause
  of other callbacks.

  Example:

  The Nylas `templates` package uses this method to see if the user has
  populated a `<code>` tag placed in the body and change it's CSS class to
  reflect that it is no longer empty.

  ```coffee
  onContentChanged: ({editor, mutations}) ->
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
  @onContentChanged: ({editor, mutations}) ->

  @onContentStoppedChanging: ({editor, mutations}) ->

  ###
  Public: Override onBlur to mutate the contenteditable DOM node whenever the
  onBlur event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - editor: The {Editor} controller that provides a host of convenience
  methods for manipulating the selection and DOM
  - event: DOM event fired on the contenteditable
  ###
  @onBlur: ({editor, event}) ->

  ###
  Public: Override onFocus to mutate the contenteditable DOM node whenever the
  onFocus event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - editor: The {Editor} controller that provides a host of convenience
  methods for manipulating the selection and DOM
  - event: DOM event fired on the contenteditable
  ###
  @onFocus: ({editor, event}) ->

  ###
  Public: Override onClick to mutate the contenteditable DOM node whenever the
  onClick event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - editor: The {Editor} controller that provides a host of convenience
  methods for manipulating the selection and DOM
  - event: DOM event fired on the contenteditable
  ###
  @onClick: ({editor, event}) ->

  ###
  Public: Override onKeyDown to mutate the contenteditable DOM node whenever the
  onKeyDown event is fired on it.
  Public: Called when the user presses a key while focused on the contenteditable's body field.
  Override onKeyDown in your ContenteditableExtension to adjust the selection or
  perform other actions.

  If your package implements key down behavior for a particular scenario, you
  should prevent the default behavior of the key via `event.preventDefault()`.
  You may mutate the contenteditable in place, we not expect any return value
  from this method.

  Important: You should prevent the default key down behavior with great care.

  - editor: The {Editor} controller that provides a host of convenience
  methods for manipulating the selection and DOM
  - event: DOM event fired on the contenteditable
  ###
  @onKeyDown: ({editor, event}) ->

  ###
  Public: Override onShowContextMenu to add new menu items to the right click menu
  inside the contenteditable.

  - editor: The {Editor} controller that provides a host of convenience
  methods for manipulating the selection and DOM
  - event: DOM event fired on the contenteditable
  - menu: [Menu](https://github.com/atom/electron/blob/master/docs/api/menu.md)
  object you can mutate in order to add new [MenuItems](https://github.com/atom/electron/blob/master/docs/api/menu-item.md)
  to the context menu that will be displayed when you right click the contenteditable.
  ###
  @onShowContextMenu: ({editor, event, menu}) ->

  ###
  Public: Override `keyCommandHandlers` to declaratively map keyboard
  commands to callbacks.

  Return an object keyed by the command name whose values are the
  callbacks.

  Callbacks are automatically bound to the Contenteditable context and
  passed `({editor, event})` as its argument.

  New commands are defined in keymap.cson files.
  ###
  @keyCommandHandlers: =>

  ###
  Public: Override `toolbarButtons` to declaratively add your own button
  to the composer's toolbar.

  - toolbarState: The current state of the Toolbar and Composer. This is
  Read only.

  Must return an array of objects obeying the following spec:
    - className: A string class name
    - onClick: Callback to fire when your button is clicked. The callback
    is automatically bound to the editor and will get passed an single
    object with the following args.
      - editor - The {Editor} controller for manipulating the DOM
      - event - The click Event object
    - tooltip: A string to display when users hover over your button
    - iconUrl: A url for the icon.
  ###
  @toolbarButtons: ({toolbarState}) ->

  ###
  Public: Override `toolbarComponentConfig` to declaratively show your own
  toolbar when certain conditions are met.

  If you want to hide your toolbar component, return null.

  If you want to display your toolbar, then return an object with the
  signature indicated below.

  This methods gets called anytime the `toolbarState` changes. Since
  `toolbarState` includes the current value of the Selection and any
  objects a user is hovering over, you should expect it to change very
  frequently.

  - toolbarState: The current state of the Toolbar and Composer. This is
  Read only.
    - dragging
    - doubleDown
    - hoveringOver
    - editableNode
    - exportedSelection
    - extensions
    - atomicEdit

  Must return an object with the following signature
    - component: A React component or null.
    - props: Props to be passed into your custom Component
    - locationRefNode: Anything (usually a DOM Node) that responds to
    `getBoundingClientRect`. This is used to determine where to display
    your component.
    - width: The width of your component. This is necessary because when
    your component is displayed in the {FloatingToolbar}, the position is
    pre-computed based on the absolute width of the item.
  ###
  @toolbarComponentConfig: ({toolbarState}) ->

module.exports = ContenteditableExtension
