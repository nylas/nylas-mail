ClipboardService = require '../../src/components/contenteditable/clipboard-service'

describe "ClipboardService", ->
  beforeEach ->
    @onFilePaste = jasmine.createSpy('onFilePaste')
    @clipboardService = new ClipboardService

  describe "when html and plain text parts are present", ->
    beforeEach ->
      @mockEvent =
        preventDefault: jasmine.createSpy('preventDefault')
        clipboardData:
          getData: ->
            return '<strong>This is text</strong>' if 'text/html'
            return 'This is plain text' if 'text/plain'
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

    it "should sanitize the HTML string and call insertHTML", ->
      spyOn(document, 'execCommand')
      spyOn(@clipboardService, '_sanitizeInput').andCallThrough()

      runs ->
        @clipboardService.onPaste(@mockEvent)
      waitsFor ->
        document.execCommand.callCount > 0
      runs ->
        expect(@clipboardService._sanitizeInput).toHaveBeenCalledWith('<strong>This is text</strong>', 'text/html')
        [command, a, html] = document.execCommand.mostRecentCall.args
        expect(command).toEqual('insertHTML')
        expect(html).toEqual('<strong>This is text</strong>')

  describe "when html and plain text parts are present", ->
    beforeEach ->
      @mockEvent =
        preventDefault: jasmine.createSpy('preventDefault')
        clipboardData:
          getData: ->
            return 'This is plain text' if 'text/plain'
            return null
          items: [{
            kind: 'string'
            type: 'text/plain'
            getAsString: -> 'This is plain text'
          }]

    it "should sanitize the plain text string and call insertHTML", ->
      spyOn(document, 'execCommand')
      spyOn(@clipboardService, '_sanitizeInput').andCallThrough()

      runs ->
        @clipboardService.onPaste(@mockEvent)
      waitsFor ->
        document.execCommand.callCount > 0
      runs ->
        expect(@clipboardService._sanitizeInput).toHaveBeenCalledWith('This is plain text', 'text/html')
        [command, a, html] = document.execCommand.mostRecentCall.args
        expect(command).toEqual('insertHTML')
        expect(html).toEqual('This is plain text')

  describe "sanitization", ->
    tests = [
      {
        in: ""
        sanitizedAsHTML: ""
        sanitizedAsPlain: ""
      },
      {
        in: "Hello World"
        sanitizedAsHTML: "Hello World"
        sanitizedAsPlain: "Hello World"
      },
      {
        in: "  Hello  World"
        # Should collapse to 1 space when rendered
        sanitizedAsHTML: "  Hello  World"
        # Preserving 2 spaces
        sanitizedAsPlain: " &nbsp;Hello &nbsp;World"
      },
      {
        in: "   Hello   World"
        sanitizedAsHTML: "   Hello   World"
        # Preserving 3 spaces
        sanitizedAsPlain: " &nbsp; Hello &nbsp; World"
      },
      {
        in: "    Hello    World"
        sanitizedAsHTML: "    Hello    World"
        # Preserving 4 spaces
        sanitizedAsPlain: " &nbsp; &nbsp;Hello &nbsp; &nbsp;World"
      },
      {
        in: "Hello\nWorld"
        sanitizedAsHTML: "Hello<br />World"
        # Convert newline to br
        sanitizedAsPlain: "Hello<br/>World"
      },
      {
        in: "Hello\rWorld"
        sanitizedAsHTML: "Hello<br />World"
        # Convert carriage return to br
        sanitizedAsPlain: "Hello<br/>World"
      },
      {
        in: "Hello\n\n\nWorld"
        # Never have more than 2 br's in a row
        sanitizedAsHTML: "Hello<br/><br/>World"
        # Convert multiple newlines to same number of brs
        sanitizedAsPlain: "Hello<br/><br/><br/>World"
      },
      {
        in: "<style>Yo</style> Foo Bar <div>Baz</div>"
        # Strip bad tags
        sanitizedAsHTML: " Foo Bar Baz"
        # HTML encode tags for literal display
        sanitizedAsPlain: "&lt;style&gt;Yo&lt;/style&gt; Foo Bar &lt;div&gt;Baz&lt;/div&gt;"
      },
      {
        in: "<script>Bah</script> Yo < script>Boo! < / script >"
        # Strip non white-list tags and encode malformed ones.
        sanitizedAsHTML: " Yo &lt; script&gt;Boo! &lt; / script &gt;"
        # HTML encode tags for literal display
        sanitizedAsPlain: "&lt;script&gt;Bah&lt;/script&gt; Yo &lt; script&gt;Boo! &lt; / script &gt;"
      },
      {
        in: """
        <!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
        <html>
        <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
        <meta http-equiv="Content-Style-Type" content="text/css">
        <title></title>
        <meta name="Generator" content="Cocoa HTML Writer">
        <meta name="CocoaVersion" content="1265.21">
        <style type="text/css">
        li.li1 {margin: 0.0px 0.0px 0.0px 0.0px; font: 12.0px Helvetica}
        ul.ul1 {list-style-type: disc}
        </style>
        </head>
        <body>
        <ul class="ul1">
        <li class="li1"><b>Packet pickup: </b>I'll pick up my packet at some point on Saturday at Fort Mason. Let me know if you'd like me to get yours. I'll need a photo of your ID and your confirmation number. Also, shirt color preference, I believe. Gray or black? Can't remember...</li>
        </ul>
        </body>
        </html>"""
        # Strip non white-list tags and encode malformed ones.
        sanitizedAsHTML: "<ul><br /><li><b>Packet pickup: </b>I'll pick up my packet at some point on Saturday at Fort Mason. Let me know if you'd like me to get yours. I'll need a photo of your ID and your confirmation number. Also, shirt color preference, I believe. Gray or black? Can't remember...</li><br /></ul>"
        # HTML encode tags for literal display
        sanitizedAsPlain: "&lt;!DOCTYPE html PUBLIC &#34;-//W3C//DTD HTML 4.01//EN&#34; &#34;http://www.w3.org/TR/html4/strict.dtd&#34;&gt;<br/>&lt;html&gt;<br/>&lt;head&gt;<br/>&lt;meta http-equiv=&#34;Content-Type&#34; content=&#34;text/html; charset=UTF-8&#34;&gt;<br/>&lt;meta http-equiv=&#34;Content-Style-Type&#34; content=&#34;text/css&#34;&gt;<br/>&lt;title&gt;&lt;/title&gt;<br/>&lt;meta name=&#34;Generator&#34; content=&#34;Cocoa HTML Writer&#34;&gt;<br/>&lt;meta name=&#34;CocoaVersion&#34; content=&#34;1265.21&#34;&gt;<br/>&lt;style type=&#34;text/css&#34;&gt;<br/>li.li1 {margin: 0.0px 0.0px 0.0px 0.0px; font: 12.0px Helvetica}<br/>ul.ul1 {list-style-type: disc}<br/>&lt;/style&gt;<br/>&lt;/head&gt;<br/>&lt;body&gt;<br/>&lt;ul class=&#34;ul1&#34;&gt;<br/>&lt;li class=&#34;li1&#34;&gt;&lt;b&gt;Packet pickup: &lt;/b&gt;I'll pick up my packet at some point on Saturday at Fort Mason. Let me know if you'd like me to get yours. I'll need a photo of your ID and your confirmation number. Also, shirt color preference, I believe. Gray or black? Can't remember...&lt;/li&gt;<br/>&lt;/ul&gt;<br/>&lt;/body&gt;<br/>&lt;/html&gt;"
      }
    ]

    it "sanitizes plain text properly", ->
      for test in tests
        expect(@clipboardService._sanitizeInput(test.in, "text/plain")).toBe test.sanitizedAsPlain

    it "sanitizes html text properly", ->
      for test in tests
        expect(@clipboardService._sanitizeInput(test.in, "text/html")).toBe test.sanitizedAsHTML
