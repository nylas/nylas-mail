{Utils} = require 'nylas-exports'
sanitizeHtml = require 'sanitize-html'

class ClipboardService
  constructor: ({@onFilePaste}={}) ->

  onPaste: (evt) =>
    return if evt.clipboardData.items.length is 0
    evt.preventDefault()

    # If the pasteboard has a file on it, stream it to a teporary
    # file and fire our `onFilePaste` event.
    item = evt.clipboardData.items[0]

    if item.kind is 'file'
      blob = item.getAsFile()
      ext = {'image/png': '.png', 'image/jpg': '.jpg', 'image/tiff': '.tiff'}[item.type] ? ''
      temp = require 'temp'
      path = require 'path'
      fs = require 'fs'

      reader = new FileReader()
      reader.addEventListener 'loadend', =>
        buffer = new Buffer(new Uint8Array(reader.result))
        tmpFolder = temp.path('-nylas-attachment')
        tmpPath = path.join(tmpFolder, "Pasted File#{ext}")
        fs.mkdir tmpFolder, =>
          fs.writeFile tmpPath, buffer, (err) =>
            @onFilePaste?(tmpPath)
      reader.readAsArrayBuffer(blob)

    else
      # Look for text/html in any of the clipboard items and fall
      # back to text/plain.
      inputText = evt.clipboardData.getData("text/html") ? ""
      type = "text/html"
      if inputText.length is 0
        inputText = evt.clipboardData.getData("text/plain") ? ""
        type = "text/plain"

      if inputText.length > 0
        cleanHtml = @_sanitizeInput(inputText, type)
        document.execCommand("insertHTML", false, cleanHtml)

    return

  # This is used primarily when pasting text in
  _sanitizeInput: (inputText="", type="text/html") =>
    if type is "text/plain"
      inputText = Utils.encodeHTMLEntities(inputText)
      inputText = inputText.replace(/[\r\n]|&#1[03];/g, "<br/>").
                            replace(/\s\s/g, " &nbsp;")
    else
      inputText = sanitizeHtml inputText.replace(/[\n\r]/g, "<br/>"),
        allowedTags: ['p', 'b', 'i', 'em', 'strong', 'a', 'br', 'img', 'ul', 'ol', 'li', 'strike']
        allowedAttributes:
          a: ['href', 'name']
          img: ['src', 'alt']
        transformTags:
          h1: "p"
          h2: "p"
          h3: "p"
          h4: "p"
          h5: "p"
          h6: "p"
          div: "p"
          pre: "p"
          blockquote: "p"
          table: "p"

      # We sanitized everything and convert all whitespace-inducing
      # elements into <p> tags. We want to de-wrap <p> tags and replace
      # with two line breaks instead.
      inputText = inputText.replace(/<p[\s\S]*?>/gim, "").
                            replace(/<\/p>/gi, "<br/>")

      # We never want more then 2 line breaks in a row.
      # https://regex101.com/r/gF6bF4/4
      inputText = inputText.replace(/(<br\s*\/?>\s*){3,}/g, "<br/><br/>")

      # We never want to keep leading and trailing <brs>, since the user
      # would have started a new paragraph themselves if they wanted space
      # before what they paste.
      # BAD:    "<p>begins at<br>12AM</p>" => "<br><br>begins at<br>12AM<br><br>"
      # Better: "<p>begins at<br>12AM</p>" => "begins at<br>12"
      inputText = inputText.replace(/^(<br ?\/>)+/, '')
      inputText = inputText.replace(/(<br ?\/>)+$/, '')

    return inputText

module.exports = ClipboardService
