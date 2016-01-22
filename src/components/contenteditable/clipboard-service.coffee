ContenteditableService = require './contenteditable-service'

{InlineStyleTransformer,
 SanitizeTransformer,
 Utils} = require 'nylas-exports'

class ClipboardService extends ContenteditableService
  constructor: (args...) ->
    super(args...)
    @onFilePaste = @props.onFilePaste

  setData: (args...) ->
    super(args...)
    @onFilePaste = @props.onFilePaste

  eventHandlers: -> {@onPaste}

  onPaste: (event) =>
    return if event.clipboardData.items.length is 0
    event.preventDefault()

    # If the pasteboard has a file on it, stream it to a teporary
    # file and fire our `onFilePaste` event.
    item = event.clipboardData.items[0]

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
      {input, mimetype} = @_getBestRepresentation(event.clipboardData)

      if mimetype is 'text/plain'
        input = Utils.encodeHTMLEntities(input)
        input = input.replace(/[\r\n]|&#1[03];/g, "<br/>").replace(/\s\s/g, " &nbsp;")
        document.execCommand("insertHTML", false, input)

      else if mimetype is 'text/html'
        @_sanitizeHTMLInput(input).then (cleanHtml) ->
          document.execCommand("insertHTML", false, cleanHtml)

      else
        # Do nothing. No appropriate format is available

    return

  _getBestRepresentation: (clipboardData) =>
    for mimetype in ["text/html", "text/plain"]
      data = clipboardData.getData(mimetype) ? ""
      if data.length > 0
        return {input: data, mimetype: mimetype}

    return {input: null, mimetype: null}

  # This is used primarily when pasting text in
  _sanitizeHTMLInput: (input) =>
    InlineStyleTransformer.run(input).then (input) =>
      SanitizeTransformer.run(input, SanitizeTransformer.Preset.Permissive).then (input) =>
        # We never want more then 2 line breaks in a row.
        # https://regex101.com/r/gF6bF4/4
        input = input.replace(/(<br\s*\/?>\s*){3,}/g, "<br/><br/>")

        # We never want to keep leading and trailing <brs>, since the user
        # would have started a new paragraph themselves if they wanted space
        # before what they paste.
        # BAD:    "<p>begins at<br>12AM</p>" => "<br><br>begins at<br>12AM<br><br>"
        # Better: "<p>begins at<br>12AM</p>" => "begins at<br>12"
        input = input.replace(/^(<br ?\/>)+/, '')
        input = input.replace(/(<br ?\/>)+$/, '')

        Promise.resolve(input)

module.exports = ClipboardService
