ClipboardService = require '../../src/components/contenteditable/clipboard-service'
{InlineStyleTransformer, SanitizeTransformer} = require 'nylas-exports'
fs = require 'fs'

describe "ClipboardService", ->
  beforeEach ->
    @onFilePaste = jasmine.createSpy('onFilePaste')
    @setInnerState = jasmine.createSpy('setInnerState')
    @clipboardService = new ClipboardService
      data: {props: {@onFilePaste}}
      methods: {@setInnerState}

    spyOn(document, 'execCommand')

  describe "when both html and plain text parts are present", ->
    beforeEach ->
      @mockEvent =
        preventDefault: jasmine.createSpy('preventDefault')
        clipboardData:
          getData: (mimetype) ->
            return '<strong>This is text</strong>' if mimetype is 'text/html'
            return 'This is plain text' if mimetype is 'text/plain'
            return null
          items: [{
            kind: 'string'
            type: 'text/html'
            getAsString: -> '<strong>This is text</strong>'
          },{
            kind: 'string'
            type: 'text/plain'
            getAsString: -> 'This is plain text'
          }]

    it "should choose to insert the HTML representation", ->
      spyOn(@clipboardService, '_sanitizeHTMLInput').andCallFake (input) =>
        Promise.resolve(input)

      runs ->
        @clipboardService.onPaste(@mockEvent)
      waitsFor ->
        document.execCommand.callCount > 0
      runs ->
        [command, a, html] = document.execCommand.mostRecentCall.args
        expect(command).toEqual('insertHTML')
        expect(html).toEqual('<strong>This is text</strong>')

  describe "when only plain text is present", ->
    beforeEach ->
      @mockEvent =
        preventDefault: jasmine.createSpy('preventDefault')
        clipboardData:
          getData: (mimetype) ->
            return 'This is plain text\nAnother line  Hello  World' if mimetype is 'text/plain'
            return null
          items: [{
            kind: 'string'
            type: 'text/plain'
            getAsString: -> 'This is plain text\nAnother line  Hello  World'
          }]

    it "should convert the plain text to HTML and call insertHTML", ->
      runs ->
        @clipboardService.onPaste(@mockEvent)
      waitsFor ->
        document.execCommand.callCount > 0
      runs ->
        [command, a, html] = document.execCommand.mostRecentCall.args
        expect(command).toEqual('insertHTML')
        expect(html).toEqual('This is plain text<br/>Another line &nbsp;Hello &nbsp;World')

  describe "HTML sanitization", ->
    beforeEach ->
      spyOn(InlineStyleTransformer, 'run').andCallThrough()
      spyOn(SanitizeTransformer, 'run').andCallThrough()

    it "should inline CSS styles and run the standard permissive HTML sanitizer", ->
      input = "HTML HERE"
      @clipboardService._sanitizeHTMLInput(input)
      advanceClock()
      expect(InlineStyleTransformer.run).toHaveBeenCalledWith(input)
      advanceClock()
      expect(SanitizeTransformer.run).toHaveBeenCalledWith(input, SanitizeTransformer.Preset.Permissive)

    it "should replace two or more <br/>s in a row", ->
      tests = [{
        in: "Hello\n\n\nWorld"
        out: "Hello<br/><br/>World"
      },{
        in: "Hello<br/><br/><br/><br/>World"
        out: "Hello<br/><br/>World"
      }]
      for test in tests
        waitsForPromise =>
          @clipboardService._sanitizeHTMLInput(test.in).then (out) ->
            expect(out).toBe(test.out)


    it "should remove all leading and trailing <br/>s from the text", ->
      tests = [{
        in: "<br/><br/>Hello<br/>World"
        out: "Hello<br/>World"
      },{
        in: "<br/><br/>Hello<br/><br/><br/><br/>"
        out: "Hello"
      }]
      for test in tests
        waitsForPromise =>
          @clipboardService._sanitizeHTMLInput(test.in).then (out) ->
            expect(out).toBe(test.out)

  # Unfortunately, it doesn't seem we can do real IPC (to `juice` in the main process)
  # so these tests are non-functional.
  xdescribe "real-world examples", ->
    it "should produce the correct output", ->
      scenarios = []
      fixtures = path.resolve('./spec/fixtures/paste')
      for filename in fs.readdirSync(fixtures)
        if filename[-8..-1] is '-in.html'
          scenarios.push
            in: fs.readFileSync(path.join(fixtures, filename)).toString()
            out: fs.readFileSync(path.join(fixtures, "#{filename[0..-9]}-out.html")).toString()

      scenarios.forEach (scenario) =>
        @clipboardService._sanitizeHTMLInput(scenario.in).then (out) ->
          expect(out).toBe(scenario.out)
