{Emitter, CompositeDisposable} = require 'event-kit'

class StylesElement extends HTMLElement
  subscriptions: null
  context: null

  onDidAddStyleElement: (callback) ->
    @emitter.on 'did-add-style-element', callback

  onDidRemoveStyleElement: (callback) ->
    @emitter.on 'did-remove-style-element', callback

  onDidUpdateStyleElement: (callback) ->
    @emitter.on 'did-update-style-element', callback

  createdCallback: ->
    @emitter = new Emitter
    @styleElementClonesByOriginalElement = new WeakMap

  attachedCallback: ->
    @initialize()

  detachedCallback: ->
    @subscriptions.dispose()
    @subscriptions = null

  attributeChangedCallback: (attrName, oldVal, newVal) ->
    @contextChanged() if attrName is 'context'

  initialize: ->
    return if @subscriptions?

    @subscriptions = new CompositeDisposable
    @context = @getAttribute('context') ? undefined

    @subscriptions.add NylasEnv.styles.observeStyleElements(@styleElementAdded.bind(this))
    @subscriptions.add NylasEnv.styles.onDidRemoveStyleElement(@styleElementRemoved.bind(this))
    @subscriptions.add NylasEnv.styles.onDidUpdateStyleElement(@styleElementUpdated.bind(this))

  contextChanged: ->
    return unless @subscriptions?

    @styleElementRemoved(child) for child in Array::slice.call(@children)
    @context = @getAttribute('context')
    @styleElementAdded(styleElement) for styleElement in NylasEnv.styles.getStyleElements()

  styleElementAdded: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = styleElement.cloneNode(true)
    styleElementClone.sourcePath = styleElement.sourcePath
    styleElementClone.context = styleElement.context
    styleElementClone.priority = styleElement.priority
    @styleElementClonesByOriginalElement.set(styleElement, styleElementClone)

    priority = styleElement.priority
    if priority?
      for child in @children
        if child.priority > priority
          insertBefore = child
          break

    @insertBefore(styleElementClone, insertBefore)
    @emitter.emit 'did-add-style-element', styleElementClone

  styleElementRemoved: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement) ? styleElement
    styleElementClone.remove()
    @emitter.emit 'did-remove-style-element', styleElementClone

  styleElementUpdated: (styleElement) ->
    return unless @styleElementMatchesContext(styleElement)

    styleElementClone = @styleElementClonesByOriginalElement.get(styleElement)
    styleElementClone.textContent = styleElement.textContent
    @emitter.emit 'did-update-style-element', styleElementClone

  styleElementMatchesContext: (styleElement) ->
    not @context? or styleElement.context is @context

module.exports = StylesElement = document.registerElement 'nylas-styles', prototype: StylesElement.prototype
