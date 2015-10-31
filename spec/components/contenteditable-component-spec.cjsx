# This tests the basic Contenteditable component. For various modules of
# the contenteditable (such as selection, tooltip, quoting, etc) see the
# related test files.
#
_ = require "underscore"
fs = require 'fs'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
Contenteditable = require "../../src/components/contenteditable/contenteditable",

describe "Contenteditable", ->
  beforeEach ->
    @onChange = jasmine.createSpy('onChange')
    html = 'Test <strong>HTML</strong>'
    @component = ReactTestUtils.renderIntoDocument(
      <Contenteditable html={html} onChange={@onChange}/>
    )
    @editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@component, 'contentEditable'))

  describe "render", ->
    it 'should render into the document', ->
      expect(ReactTestUtils.isCompositeComponentWithType @component, Contenteditable).toBe true

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

  describe "pasting", ->
    beforeEach ->

    describe "when a file item is present", ->
      beforeEach ->
        @mockEvent =
          preventDefault: jasmine.createSpy('preventDefault')
          clipboardData:
            items: [{
              kind: 'file'
              type: 'image/png'
              getAsFile: -> new Blob(['12341352312411'], {type : 'image/png'})
            }]

      it "should save the image to a temporary file and call `onFilePaste`", ->
        onPaste = jasmine.createSpy('onPaste')
        @component = ReactTestUtils.renderIntoDocument(
          <Contenteditable html={''} onChange={@onChange} onFilePaste={onPaste} />
        )
        @editableNode = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@component, 'contentEditable'))
        runs ->
          ReactTestUtils.Simulate.paste(@editableNode, @mockEvent)
        waitsFor ->
          onPaste.callCount > 0
        runs ->
          path = require('path')
          file = onPaste.mostRecentCall.args[0]
          expect(path.basename(file)).toEqual('Pasted File.png')
          contents = fs.readFileSync(file)
          expect(contents.toString()).toEqual('12341352312411')

