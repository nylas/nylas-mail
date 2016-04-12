# This tests just quoted text within a contenteditable.
#
# For a test of the basic component itself see
# contenteditable-component-spec.cjsx
#
_ = require "underscore"
React = require "react"
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

Fields = require '../lib/fields'
Composer = require "../lib/composer-view"
ComposerEditor = require '../lib/composer-editor'

{Message, DraftStore, ComponentRegistry} = require 'nylas-exports'

describe "Composer Quoted Text", ->
  beforeEach ->
    ComponentRegistry.register(ComposerEditor, role: "Composer:Editor")

    @onChange = jasmine.createSpy('onChange')
    @htmlNoQuote = 'Test <strong>HTML</strong><br>'
    @htmlWithQuote = 'Test <strong>HTML</strong><br><blockquote class="gmail_quote">QUOTE</blockquote>'

    @draft = new Message(draft: true, clientId: "client-123")
    @session =
      trigger: ->
      changes:
        add: ->
      draft: => @draft

  afterEach ->
    DraftStore._cleanupAllSessions()
    ComposerEditor.containerRequired = undefined
    ComponentRegistry.unregister(ComposerEditor)

  # Must be called with the test's scope
  setHTML = (newHTML) ->
    @$contentEditable.innerHTML = newHTML
    @contentEditable._onDOMMutated(["mutated"])

  describe "quoted-text-control toggle button", ->

  describe "when there's no quoted text", ->
    beforeEach ->
      @draft.body = @htmlNoQuote
      @composer = ReactTestUtils.renderIntoDocument(
        <Composer draft={@draft} session={@session}/>
      )
      @composer.setState
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = ReactDOM.findDOMNode(@contentEditable).querySelector('[contenteditable]')
      @$composerBodyWrap = ReactDOM.findDOMNode(@composer.refs.composerBodyWrap)

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "allows the text to update", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      spyOn(@composer, "_addToProxy")
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(textToAdd + @htmlNoQuote)

    it 'should not render the quoted-text-control toggle', ->
      toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@composer, 'quoted-text-control')
      expect(toggles.length).toBe 0


  describe 'when there is quoted text, and showQuotedText is true', ->
    beforeEach ->
      @draft.body = @htmlWithQuote
      @composer = ReactTestUtils.renderIntoDocument(
        <Composer draft={@draft} session={@session}/>
      )
      @composer.setState
        showQuotedText: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = ReactDOM.findDOMNode(@contentEditable).querySelector('[contenteditable]')
      @$composerBodyWrap = ReactDOM.findDOMNode(@composer.refs.composerBodyWrap)

    it 'should display the quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote

    it "should call `_addToProxy` with the entire HTML string", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      spyOn(@composer, "_addToProxy")
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, textToAdd + @htmlWithQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(textToAdd + @htmlWithQuote)

    it "should allow the quoted text to be changed", ->
      newText = 'Test <strong>NEW 1 HTML</strong><blockquote class="gmail_quote">QUOTE CHANGED!!!</blockquote>'
      spyOn(@composer, "_addToProxy")
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, newText)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      expect(ev).toEqual(newText)

    describe 'quoted text control toggle button', ->
      beforeEach ->
        @toggle = ReactTestUtils.findRenderedDOMComponentWithClass(@composer, 'quoted-text-control')

      it 'should be rendered', ->
        expect(@toggle).toBeDefined()

  describe 'when there is quoted text, an showQuotedText is false', ->
    beforeEach ->
      @draft.body = @htmlWithQuote
      @composer = ReactTestUtils.renderIntoDocument(
        <Composer draft={@draft} session={@session}/>
      )
      @composer.setState
        showQuotedText: false
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = ReactDOM.findDOMNode(@contentEditable).querySelector('[contenteditable]')
      @$composerBodyWrap = ReactDOM.findDOMNode(@composer.refs.composerBodyWrap)

    # The quoted text dom parser wraps stuff inertly in body tags
    wrapBody = (html) -> "<head></head><body>#{html}</body>"

    it 'should not display any quoted text', ->
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote

    it "should let you change the text, and then append the quoted text part to the end before firing `_addToProxy`", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      spyOn(@composer, "_addToProxy")
      expect(@$contentEditable.innerHTML).toBe @htmlNoQuote
      setHTML.call(@, textToAdd + @htmlNoQuote)
      ev = @composer._addToProxy.mostRecentCall.args[0].body
      # Note that we expect the version WITH a quote while setting the
      # version withOUT a quote.
      expect(ev).toEqual(wrapBody(textToAdd + @htmlWithQuote))

    it "should let you add more html that looks like quoted text, and still properly appends the old quoted text", ->
      textToAdd = "Yo <blockquote class=\"gmail_quote\">I'm a fake quote</blockquote>"
      spyOn(@composer, "_addToProxy")
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
