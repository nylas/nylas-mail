# This tests the basic Contenteditable component. For various modules of
# the contenteditable (such as selection, tooltip, quoting, etc) see the
# related test files.
#
_ = require "underscore-plus"
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
ContenteditableComponent = require "../lib/contenteditable-component.cjsx",

describe "ContenteditableComponent", ->
  beforeEach ->
    @onChange = jasmine.createSpy('onChange')
    html = 'Test <strong>HTML</strong>'
    @component = ReactTestUtils.renderIntoDocument(
      <ContenteditableComponent html={html} onChange={@onChange}/>
    )
    @editableNode = ReactTestUtils.findRenderedDOMComponentWithAttr(@component, 'contentEditable').getDOMNode()

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
