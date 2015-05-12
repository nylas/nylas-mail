# This tests the basic Contenteditable component. For various modules of
# the contenteditable (such as selection, tooltip, quoting, etc) see the
# related test files.
#
_ = require "underscore-plus"
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
ContenteditableComponent = require "../lib/contenteditable-component",

describe "ContenteditableComponent", ->
  beforeEach ->
    @onChange = jasmine.createSpy('onChange')
    html = 'Test <strong>HTML</strong>'
    @component = ReactTestUtils.renderIntoDocument(
      <ContenteditableComponent html={html} onChange={@onChange}/>
    )
    @editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@component, 'contentEditable'))

  describe "render", ->
    it 'should render into the document', ->
      expect(ReactTestUtils.isCompositeComponentWithType @component, ContenteditableComponent).toBe true

    it "should include a content-editable div", ->
      expect(@editableNode).toBeDefined()

  describe "when the html is changed", ->
    beforeEach ->
      @changedHtmlWithoutQuote = 'Changed <strong>NEW 1 HTML</strong><br>'

      @performEdit = (newHTML, component = @component) =>
        @editableNode.innerHTML = newHTML
        ReactTestUtils.Simulate.input(@editableNode, {target: {value: newHTML}})

    it "should fire `props.onChange`", ->
      @performEdit('Test <strong>New HTML</strong>')
      expect(@onChange).toHaveBeenCalled()

    # One day we may make this more efficient. For now we aggressively
    # re-render because of the manual cursor positioning.
    it "should fire if the html is the same", ->
      expect(@onChange.callCount).toBe(0)
      @performEdit(@changedHtmlWithoutQuote)
      expect(@onChange.callCount).toBe(1)
      @performEdit(@changedHtmlWithoutQuote)
      expect(@onChange.callCount).toBe(2)

  describe "pasting behavior", ->
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
        sanitizedAsHTML: " Foo Bar Baz<br/>"
        # HTML encode tags for literal display
        sanitizedAsPlain: "&lt;style&gt;Yo&lt;/style&gt; Foo Bar &lt;div&gt;Baz&lt;/div&gt;"
      }
      {
        in: "<script>Bah</script> Yo < script>Boo! < / script >"
        # Strip non white-list tags and encode malformed ones.
        sanitizedAsHTML: " Yo &lt; script&gt;Boo! &lt; / script &gt;"
        # HTML encode tags for literal display
        sanitizedAsPlain: "&lt;script&gt;Bah&lt;/script&gt; Yo &lt; script&gt;Boo! &lt; / script &gt;"
      }
    ]

    it "sanitizes plain text properly", ->
      for test in tests
        expect(@component._sanitizeInput(test.in, "text/plain")).toBe test.sanitizedAsPlain

    it "sanitizes html text properly", ->
      for test in tests
        expect(@component._sanitizeInput(test.in, "text/html")).toBe test.sanitizedAsHTML
