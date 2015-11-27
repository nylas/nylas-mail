###
Public: ContenteditableExtension is an abstract base class. Implementations of this
are used to make additional changes to a <Contenteditable /> component
beyond a user's input intents. The hooks in this class provide the contenteditable
DOM Node itself, allowing you to adjust selection ranges and change content
as necessary.

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

If you specifically want to enhance the Composer experience you should register
a {ComposerExtension}

Section: Extensions
###
class ContenteditableExtension

  ###
  Public: Override onInput in your Contenteditable subclass to implement custom
  behavior as the user types in the contenteditable's body field. You may mutate
  the contenteditable in place, we do not expect any return value from this method.

  The onInput event can be triggered by a variety of events, some of which could
  have been already been looked at by a callback. Almost any DOM mutation will
  fire this event. Sometimes those mutations are the cause of other callbacks.

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable

  Example:

  The Nylas `templates` package uses this method to see if the user has populated a
  `<code>` tag placed in the body and change it's CSS class to reflect that it is no
  longer empty.

  ```coffee
  onInput: (event, editableNode, selection) ->
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
  @onInput: (event, editableNode, selection) ->

  ###
  Public: Override onBlur to mutate the contenteditable DOM node whenever the
  onBlur event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable
  ###
  @onBlur: (event, editableNode, selection) ->

  ###
  Public: Override onFocus to mutate the contenteditable DOM node whenever the
  onFocus event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable
  ###
  @onFocus: (event, editableNode, selection) ->

  ###
  Public: Override onClick to mutate the contenteditable DOM node whenever the
  onClick event is fired on it. You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable
  ###
  @onClick: (event, editableNode, selection) ->

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

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable
  ###
  @onKeyDown: (event, editableNode, selection) ->

  ###
  Public: Override onInput to mutate the contenteditable DOM node whenever the
  onInput event is fired on it.You may mutate the contenteditable in place, we
  not expect any return value from this method.

  - event: DOM event fired on the contenteditable
  - editableNode: DOM node that represents the current contenteditable.This object
  can be mutated in place to modify the Contenteditable's content
  - selection: [Selection](https://developer.mozilla.org/en-US/docs/Web/API/Selection)
  object that represents the current selection on the contenteditable
  - menu: [Menu](https://github.com/atom/electron/blob/master/docs/api/menu.md)
  object you can mutate in order to add new [MenuItems](https://github.com/atom/electron/blob/master/docs/api/menu-item.md)
  to the context menu that will be displayed when you right click the contenteditable.
  ###
  @onShowContextMenu: (event, editableNode, selection, menu) ->

module.exports = ContenteditableExtension
