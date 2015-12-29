{DOMUtils} = require 'nylas-exports'
ExtendedSelection = require './extended-selection'

# An extended interface of execCommand
#
# Muates the DOM and Selection in atomic and predictable ways.
#
# editor.select(/{{}}/).checkNode().wrapNode("code")
#
# codeTags.forEach (tag) ->
#   if testTag(tag) DOMUtils.unwrap(tag)
#
# fn: ->
#   editor.moveDown().indent().selectRight(2).wrapSelection().bold().moveToEnd()
#
#   editor.moveDown()
#   editor.selectRight()
#   editor.bold()
#   editor.indent()
#   editor.moveToEnd()
#
#   moveToEnd bold selectRight moveDown current()
#
class EditorAPI
  constructor: (@rootNode) ->
    @_extendedSelection = new ExtendedSelection(@rootNode)

  wrapSelection:(nodeName) ->
    wrapped = DOMUtils.wrap(@_selection.getRangeAt(0), nodeName)
    @select(wrapped)
    return @

  regExpSelectorAll:(regex) ->
    DOMUtils.regExpSelectorAll(@rootNode, regex)

  currentSelection: -> @_extendedSelection

  whilePreservingSelection: (fn) ->
    sel = @currentSelection().exportSelection()
    fn()
    @select(sel)

  getSelectionTextIndex: (args...) -> @_extendedSelection.getSelectionTextIndex(args...)


  collapse: (args...) -> @_extendedSelection.collapse(args...); @
  collapseToStart: (args...) -> @_extendedSelection.collapseToStart(args...); @
  collapseToEnd: (args...) -> @_extendedSelection.collapseToEnd(args...); @
  importSelection: (args...) -> @_extendedSelection.importSelection(args...); @
  select: (args...) -> @_extendedSelection.select(args...); @
  selectEnd: (args...) -> @_extendedSelection.selectEnd(args...); @
  selectAllChildren: (args...) -> @_extendedSelection.selectAllChildren(args...); @
  restoreSelectionByTextIndex: (args...) -> @_extendedSelection.restoreSelectionByTextIndex(args...); @

  backColor: (color) -> @_ec("backColor", false, color)
  bold: -> @_ec("bold", false)
  copy: -> @_ec("copy", false)
  createLink: (uri) -> @_ec("createLink", false, uri)
  cut: -> @_ec("cut", false)
  decreaseFontSize: -> @_ec("decreaseFontSize", false)
  delete: -> @_ec("delete", false)
  fontName: (fontName) -> @_ec("fontName", false, fontName)
  fontSize: (fontSize) -> @_ec("fontSize", false, fontSize)
  foreColor: (color) -> @_ec("foreColor", false, color)
  formatBlock: (tagName) -> @_ec("formatBlock", false, tagName)
  forwardDelete: -> @_ec("forwardDelete", false)
  heading: (tagName) -> @_ec("heading", false, tagName)
  hiliteColor: (color) -> @_ec("hiliteColor", false, color)
  increaseFontSize: -> @_ec("increaseFontSize", false)
  indent: -> @_ec("indent", false)
  insertHorizontalRule: -> @_ec("insertHorizontalRule", false)
  insertHTML: (html) -> @_ec("insertHTML", false, html)
  insertImage: (uri) -> @_ec("insertImage", false, uri)
  insertOrderedList: -> @_ec("insertOrderedList", false)
  insertUnorderedList: -> @_ec("insertUnorderedList", false)
  insertParagraph: -> @_ec("insertParagraph", false)
  insertText: (text) -> @_ec("insertText", false, text)
  italic: -> @_ec("italic", false)
  justifyCenter: -> @_ec("justifyCenter", false)
  justifyFull: -> @_ec("justifyFull", false)
  justifyLeft: -> @_ec("justifyLeft", false)
  justifyRight: -> @_ec("justifyRight", false)
  outdent: -> @_ec("outdent", false)
  paste: -> @_ec("paste", false)
  redo: -> @_ec("redo", false)
  removeFormat: -> @_ec("removeFormat", false)
  selectAll: -> @_ec("selectAll", false)
  strikeThrough: -> @_ec("strikeThrough", false)
  subscript: -> @_ec("subscript", false)
  superscript: -> @_ec("superscript", false)
  underline: -> @_ec("underline", false)
  undo: -> @_ec("undo", false)
  unlink: -> @_ec("unlink", false)
  styleWithCSS: (style) -> @_ec("styleWithCSS", false, style)

  normalize: -> @rootNode.normalize(); @

  contentReadOnly: -> @_notImplemented()
  enableInlineTableEditing: -> @_notImplemented()
  enableObjectResizing: -> @_notImplemented()
  insertBrOnReturn: -> @_notImplemented()
  useCSS: -> @_notImplemented()

  _ec: (args...) -> document.execCommand(args...); return @
  _notImplemented: -> throw new Error("Not implemented")

module.exports = EditorAPI
