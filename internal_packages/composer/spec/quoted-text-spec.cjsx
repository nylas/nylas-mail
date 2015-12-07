# This tests just quoted text within a contenteditable.
#
# For a test of the basic component itself see
# contenteditable-component-spec.cjsx
#
_ = require "underscore"
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

Fields = require '../lib/fields'
Composer = require "../lib/composer-view"
{DraftStore} = require 'nylas-exports'

describe "Composer Quoted Text", ->
  beforeEach ->
    @onChange = jasmine.createSpy('onChange')
    @htmlNoQuote = 'Test <strong>HTML</strong><br>'
    @htmlWithQuote = 'Test <strong>HTML</strong><br><blockquote class="gmail_quote">QUOTE</blockquote>'

    @composer = ReactTestUtils.renderIntoDocument(<Composer draftClientId="unused"/>)
    @composer._proxy = trigger: ->
    spyOn(@composer, "_addToProxy")

    spyOn(@composer, "_setupSession")
    spyOn(@composer, "_teardownForDraft")
    spyOn(@composer, "_deleteDraftIfEmpty")
    spyOn(@composer, "_renderAttachments")

  afterEach ->
    DraftStore._cleanupAllSessions()

  # Must be called with the test's scope
  setHTML = (newHTML) ->
    @$contentEditable.innerHTML = newHTML
    @contentEditable._onDOMMutated(["mutated"])

  describe "quoted-text-control toggle button", ->

  describe "when there's no quoted text", ->
    beforeEach ->
      @composer.setState
        body: @htmlNoQuote
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@contentEditable, 'contentEditable'))
      @$composerBodyWrap = React.findDOMNode(@composer.refs.composerBodyWrap)

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "allows the text to update", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(textToAdd + @htmlNoQuote)

    it 'should not render the quoted-text-control toggle', ->
      toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@composer, 'quoted-text-control')
      expect(toggles.length).toBe 0


  describe 'when showQuotedText is true', ->
    beforeEach ->
      @composer.setState
        body: @htmlWithQuote
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithAttr(@contentEditable, 'contentEditable'))
      @$composerBodyWrap = React.findDOMNode(@composer.refs.composerBodyWrap)

    it 'should display the quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote

    it "should call `_addToProxy` with the entire HTML string", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, textToAdd + @htmlWithQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(textToAdd + @htmlWithQuote)

    it "should allow the quoted text to be changed", ->
      newText = 'Test <strong>NEW 1 HTML</strong><blockquote class="gmail_quote">QUOTE CHANGED!!!</blockquote>'
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, newText)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(newText)

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, 'quoted-text-control')

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
      @$composerBodyWrap = React.findDOMNode(@composer.refs.composerBodyWrap)

    # The quoted text dom parser wraps stuff inertly in body tags
    wrapBody = (html) -> "<head></head><body>#{html}</body>"

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "should let you change the text, and then append the quoted text part to the end before firing `_addToProxy`", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      # Note that we expect the version WITH a quote while setting the
      # version withOUT a quote.
      expect(ev).toEqual(wrapBody(textToAdd + @htmlWithQuote))

    it "should let you add more html that looks like quoted text, and still properly appends the old quoted text", ->
      textToAdd = "Yo <blockquote class=\"gmail_quote\">I'm a fake quote</blockquote>"
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      # Note that we expect the version WITH a quote while setting the
      # version withOUT a quote.
      expect(ev).toEqual(wrapBody(textToAdd + @htmlWithQuote))

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, 'quoted-text-control')

      it 'should be rendered', ->
        expect(@toggle).toBeDefined()

      it 'prompts to hide the quote', ->
        expect(React.findDOMNode(@toggle).textContent).toEqual "•••Show previous"
