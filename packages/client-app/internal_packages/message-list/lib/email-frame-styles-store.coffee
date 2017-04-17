NylasStore = require 'nylas-store'

class EmailFrameStylesStore extends NylasStore

  constructor: ->

  styles: =>
    if not @_styles
      @_findStyles()
      @_listenToStyles()
    @_styles

  _findStyles: =>
    @_styles = ""
    for sheet in document.querySelectorAll('[source-path*="email-frame.less"]')
      @_styles += "\n"+sheet.innerText
    @_styles = @_styles.replace(/.ignore-in-parent-frame/g, '')
    @trigger()

  _listenToStyles: =>
    target = document.getElementsByTagName('nylas-styles')[0]
    @_mutationObserver = new MutationObserver(@_findStyles)
    @_mutationObserver.observe(target, attributes: true, subtree: true, childList: true)

  _unlistenToStyles: =>
    @_mutationObserver?.disconnect()

  module.exports = new EmailFrameStylesStore()
