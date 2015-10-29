# This tests just quoted text within a contenteditable.
#
# For a test of the basic component itself see
# contenteditable-component-spec.cjsx
#
_ = require "underscore"
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

Fields = require '../lib/fields'
Composer = require "../lib/composer-view",
{Contenteditable} = require 'nylas-component-kit'

describe "Contenteditable", ->
  beforeEach ->
    @onChange = jasmine.createSpy('onChange')
    @htmlNoQuote = 'Test <strong>HTML</strong><br>'
    @htmlWithQuote = 'Test <strong>HTML</strong><br><blockquote class="gmail_quote">QUOTE</blockquote>'

    @composer = ReactTestUtils.renderIntoDocument(<Composer draftClientId="unused"/>)
    spyOn(@composer, "_onChangeBody")

  # Must be called with the test's scope
  setHTML = (newHTML) ->
    @$contentEditable.innerHTML = newHTML
    ReactTestUtils.Simulate.input(@$contentEditable, {target: {value: newHTML}})

  describe "quoted-text-control toggle button", ->

  describe "when there's no quoted text", ->
    beforeEach ->
      @composer.setState
        body: @htmlNoQuote
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@contentEditable, 'contentEditable'))

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "allows the text to update", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._onChangeBody.mostRecentCall.args[0]
      expect(ev.target.value).toEqual(textToAdd + @htmlNoQuote)

    it 'should not render the quoted-text-control toggle', ->
      toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@contentEditable, 'quoted-text-control')
      expect(toggles.length).toBe 0


  describe 'when showQuotedText is true', ->
    beforeEach ->
      @composer.setState
        body: @htmlWithQuote
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@contentEditable, 'contentEditable'))

    it 'should display the quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote

    it "should call `_onChangeBody` with the entire HTML string", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, textToAdd + @htmlWithQuote)
      ev = @composer._onChangeBody.mostRecentCall.args[0]
      expect(ev.target.value).toEqual(textToAdd + @htmlWithQuote)

    it "should allow the quoted text to be changed", ->
      newText = 'Test <strong>NEW 1 HTML</strong><blockquote class="gmail_quote">QUOTE CHANGED!!!</blockquote>'
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, newText)
      ev = @composer._onChangeBody.mostRecentCall.args[0]
      expect(ev.target.value).toEqual(newText)

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@contentEditable, 'quoted-text-control')

      it 'should be rendered', ->
        expect(@toggle).toBeDefined()

      it 'prompts to hide the quote', ->
        expect(React.findDOMNode(@toggle).textContent).toEqual "•••Hide previous"

  describe 'when showQuotedText is false', ->
    beforeEach ->
      @composer.setState
        body: @htmlWithQuote
        showQuotedText: false
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@contentEditable, 'contentEditable'))

    # The quoted text dom parser wraps stuff inertly in body tags
    wrapBody = (html) -> "<head></head><body>#{html}</body>"

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "should let you change the text, and then append the quoted text part to the end before firing `_onChangeBody`", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._onChangeBody.mostRecentCall.args[0]
      # Note that we expect the version WITH a quote while setting the
      # version withOUT a quote.
      expect(ev.target.value).toEqual(wrapBody(textToAdd + @htmlWithQuote))

    it "should let you add more html that looks like quoted text, and still properly appends the old quoted text", ->
      textToAdd = "Yo <blockquote class=\"gmail_quote\">I'm a fake quote</blockquote>"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._onChangeBody.mostRecentCall.args[0]
      # Note that we expect the version WITH a quote while setting the
      # version withOUT a quote.
      expect(ev.target.value).toEqual(wrapBody(textToAdd + @htmlWithQuote))

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@contentEditable, 'quoted-text-control')

      it 'should be rendered', ->
        expect(@toggle).toBeDefined()

      it 'prompts to hide the quote', ->
        expect(React.findDOMNode(@toggle).textContent).toEqual "•••Show previous"
