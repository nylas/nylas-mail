###
ContenteditablePlugin is an abstract base class. Implementations of this
are used to make additional changes to a <Contenteditable /> component
beyond a user's input intents.

While some ContenteditablePlugins are included with the core
<Contenteditable /> component, others may be added via the `plugins`
prop.
###
class ContenteditablePlugin

  # The onInput event can be triggered by a variety of events, some of
  # which could have been already been looked at by a callback.
  # Pretty much any DOM mutation will fire this.
  # Sometimes those mutations are the cause of callbacks.
  @onInput: (event, editableNode, selection, innerStateProxy) ->

  @onBlur: (event, editableNode, selection, innerStateProxy) ->

  @onFocus: (event, editableNode, selection, innerStateProxy) ->

  @onClick: (event, editableNode, selection, innerStateProxy) ->

  @onKeyDown: (event, editableNode, selection, innerStateProxy) ->

  @onShowContextMenu: (event, editableNode, selection, innerStateProxy, menu) ->
