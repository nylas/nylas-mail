DOMUtils = require './dom-utils'

###
The Nylas N1 Contenteditable component relies on Chrome's (via Electron) implementation of DOM Contenteditable.

Contenteditable is problematic when multiple browser support is required. Since we only support one browser (Electron), its behavior is consistent.

Unfortunately there are still a handful of issues in its implementation.

For more reading on Contenteditable and its issues see:

- https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Content_Editable
- https://medium.com/medium-eng/why-contenteditable-is-terrible-122d8a40e480
- https://blog.whatwg.org/the-road-to-html-5-contenteditable
- https://github.com/basecamp/trix
###
class Workarounds

  @patch: ->
    return
    @origExecCommand ?= document.execCommand
    @patchOutdent()

  # As of Electron 0.29.2 `document.execCommand('outdent')` does not
  # properly work on the <li> tag of both <ul> and <ol> lists when
  # there is exactly one <li> tag.
  #
  # We must manually perform the outdent when we detect we are at at the
  # first item in a list.
  #
  # Given
  # ```html
  # <ul>
  #   <li>a</li>
  # </ul>
  # ```
  @patchOutdent: ->
    document.execCommand = (command, args...) =>
      if command is "outdent"
        @customOutdent()
      else
        @origExecCommand.apply(document, [command].concat(args))

  @customOutdent: ->
    parentList = DOMUtils.closestAtCursor("ul, ol")
    if parentList
      listItems = parentList.querySelectorAll('li')
      if listItems.length is 1
        originalText = listItems[0].innerHTML
        DOMUtils.Mutating.replaceFirstListItem(listItems[0], originalText)
      else
        @origExecCommand.call(document, "outdent")
    else
      @origExecCommand.call(document, "outdent")

  # outdentFirstListItem: (replaceWithContent) ->
  #
  # # Detects if the cursor is in the first list item.
  # detectOutdentFirstListItem: ->
  #   li = DOMUtils.closestAtCursor("li")
  #   return false if not li
  #   list = DOMUtils.closestAtCursor("ul, ol")
  #   return list.querySelectorAll('li')?[0] is li

Workarounds.patch()
module.exports = Workarounds
