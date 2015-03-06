# This tests just quoted text within a contenteditable.
#
# For a test of the basic component itself see
# contenteditable-component-spec.cjsx
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

    html = 'Test <strong>HTML</strong><br><blockquote class="gmail_quote">QUOTE</blockquote>'
    @componentWithQuote = ReactTestUtils.renderIntoDocument(
      <ContenteditableComponent html={html} onChange={@onChange}/>
    )

  describe "quoted-text-control", ->
    it "should be rendered", ->
      expect(ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-control')).toBeDefined()

    it "should be visible if the html contains quoted text", ->
      @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@componentWithQuote, 'quoted-text-control')
      expect(@toggle.props.className.indexOf('no-quoted-text') >= 0).toBe(false)

    it "should be have `show-quoted-text` if editQuotedText is true", ->
      @componentWithQuote.setState(editQuotedText: true)
      @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@componentWithQuote, 'quoted-text-control')
      expect(@toggle.props.className.indexOf('show-quoted-text') >= 0).toBe(true)

    it "should not have `show-quoted-text` if editQuotedText is false", ->
      @componentWithQuote.setState(editQuotedText: false)
      @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@componentWithQuote, 'quoted-text-control')
      expect(@toggle.props.className.indexOf('show-quoted-text') >= 0).toBe(false)

    it "should be hidden otherwise", ->
      @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@component, 'quoted-text-control')
      expect(@toggle.props.className.indexOf('no-quoted-text') >= 0).toBe(true)

  describe "when editQuotedText is false", ->
    it "should only display HTML up to the beginning of the quoted text", ->
      @editDiv = ReactTestUtils.findRenderedDOMComponentWithAttr(@componentWithQuote, 'contentEditable')
      expect(@editDiv.getDOMNode().innerHTML.indexOf('gmail_quote') >= 0).toBe(false)

  describe "when editQuotedText is true", ->
    it "should display all the HTML", ->
      @componentWithQuote.setState(editQuotedText: true)
      @editDiv = ReactTestUtils.findRenderedDOMComponentWithAttr(@componentWithQuote, 'contentEditable')
      expect(@editDiv.getDOMNode().innerHTML.indexOf('gmail_quote') >= 0).toBe(true)

  describe "editQuotedText", ->
    it "should default to false", ->
      expect(@component.state.editQuotedText).toBe(false)

  describe "when the html is changed", ->
    beforeEach ->
      @changedHtmlWithoutQuote = 'Changed <strong>NEW 1 HTML</strong><br>'
      @changedHtmlWithQuote = 'Changed <strong>NEW 1 HTML</strong><br><blockquote class="gmail_quote">QUOTE</blockquote>'

      @performEdit = (newHTML, component = @componentWithQuote) =>
        editDiv = ReactTestUtils.findRenderedDOMComponentWithAttr(component, 'contentEditable')
        editDiv.getDOMNode().innerHTML = newHTML
        ReactTestUtils.Simulate.input(editDiv, {target: {value: newHTML}})

    describe "when editQuotedText is true", ->
      it "should call `props.onChange` with the entire HTML string", ->
        @componentWithQuote.setState(editQuotedText: true)
        @performEdit(@changedHtmlWithQuote)
        ev = @onChange.mostRecentCall.args[0]
        expect(ev.target.value).toEqual(@changedHtmlWithQuote)

      it "should allow the quoted text to be changed", ->
        changed = 'Test <strong>NEW 1 HTML</strong><br><blockquote class="gmail_quote">QUOTE CHANGED!!!</blockquote>'
        @componentWithQuote.setState(editQuotedText: true)
        @performEdit(changed)
        ev = @onChange.mostRecentCall.args[0]
        expect(ev.target.value).toEqual(changed)

    describe "when editQuotedText is false", ->
      it "should call `props.onChange` with the entire HTML string, even though the div being edited only contains some of it", ->
        @componentWithQuote.setState(editQuotedText: false)
        @performEdit(@changedHtmlWithoutQuote)
        ev = @onChange.mostRecentCall.args[0]
        expect(ev.target.value).toEqual(@changedHtmlWithQuote)

      it "should work if the component does not contain quoted text", ->
        changed = 'Hallooo! <strong>NEW 1 HTML HTML HTML</strong><br>'
        @component.setState(editQuotedText: true)
        @performEdit(changed, @component)
        ev = @onChange.mostRecentCall.args[0]
        expect(ev.target.value).toEqual(changed)
