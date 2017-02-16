# This tests just quoted text within a contenteditable.
#
# For a test of the basic component itself see
# contenteditable-component-spec.cjsx
#
_ = require "underscore"
React = require "react"
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

Fields = require('../lib/fields').default
Composer = require("../lib/composer-view").default
ComposerEditor = require('../lib/composer-editor').default

{Message, DraftStore, ComponentRegistry} = require 'nylas-exports'

describe "Composer Quoted Text", ->
  beforeEach ->
    ComponentRegistry.register(ComposerEditor, role: "Composer:Editor")

    @onChange = jasmine.createSpy('onChange')
    @htmlNoQuote = 'Test <strong>HTML</strong><br>'
    @htmlWithQuote = 'Test <strong>HTML</strong><div id="n1-quoted-text-marker"></div><br><blockquote class="gmail_quote">QUOTE</blockquote>'

    @draft = new Message(draft: true, clientId: "client-123")
    @session =
      trigger: ->
      changes:
        add: jasmine.createSpy('changes.add')
      draft: => @draft

  afterEach ->
    DraftStore._cleanupAllSessions()
    ComposerEditor.containerRequired = undefined
    ComponentRegistry.unregister(ComposerEditor)

  # Must be called with the test's scope
  setHTML = (newHTML) ->
    @$contentEditable.innerHTML = newHTML
    @contentEditable._onDOMMutated(["mutated"])

  describe "when the message is a reply", ->
    beforeEach ->
      @draft.body = @htmlNoQuote
      @composer = ReactTestUtils.renderIntoDocument(
        <Composer draft={@draft} session={@session}/>
      )
      @composer.setState
        showQuotedText: false
        showQuotedTextControl: true
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = ReactDOM.findDOMNode(@contentEditable).querySelector('[contenteditable]')
      @$composerBodyWrap = ReactDOM.findDOMNode(@composer.refs.composerBodyWrap)

    it 'should render the quoted-text-control toggle', ->
      toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@composer, 'quoted-text-control')
      expect(toggles.length).toBe 1

  describe 'when the quoted text has been expanded', ->
    beforeEach ->
      @draft.body = @htmlWithQuote
      @composer = ReactTestUtils.renderIntoDocument(
        <Composer draft={@draft} session={@session}/>
      )
      @composer.setState
        showQuotedText: true
        showQuotedTextControl: false
      @contentEditable = @composer.refs[Fields.Body]
      @$contentEditable = ReactDOM.findDOMNode(@contentEditable).querySelector('[contenteditable]')
      @$composerBodyWrap = ReactDOM.findDOMNode(@composer.refs.composerBodyWrap)

    it "should call add changes with the entire HTML string", ->
      textToAdd = "MORE <strong>TEXT</strong>!"
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, textToAdd + @htmlWithQuote)
      ev = @session.changes.add.mostRecentCall.args[0].body
      expect(ev).toEqual(textToAdd + @htmlWithQuote)

    it "should allow the quoted text to be changed", ->
      newText = 'Test <strong>NEW 1 HTML</strong><blockquote class="gmail_quote">QUOTE CHANGED!!!</blockquote>'
      expect(@$contentEditable.innerHTML).toBe @htmlWithQuote
      setHTML.call(@, newText)
      ev = @session.changes.add.mostRecentCall.args[0].body
      expect(ev).toEqual(newText)

    describe 'quoted text control toggle button', ->
      it 'should not be rendered', ->
        toggles = ReactTestUtils.scryRenderedDOMComponentsWithClass(@composer, 'quoted-text-control')
        expect(toggles.length).toBe(0)
