_ = require 'underscore-plus'
React = require 'react/addons'
ReactTestUtils = React.addons.TestUtils

{InboxTestUtils,
 Namespace,
 NamespaceStore,
 Contact,
} = require 'inbox-exports'
{TokenizingTextField, Menu} = require 'ui-components'

me = new Namespace
  name: 'Test User'
  email: 'test@example.com'
  provider: 'inbox'
NamespaceStore._current = me

CustomToken = React.createClass
  render: ->
    <span>{@props.item.email}</span>

CustomSuggestion = React.createClass
  render: ->
    <span>{@props.item.email}</span>

participant1 = new Contact
  email: 'ben@nilas.com'
participant2 = new Contact
  email: 'ben@example.com'
  name: 'ben'
participant3 = new Contact
  email: 'ben@inboxapp.com'
  name: 'Duplicate email'
participant4 = new Contact
  email: 'ben@elsewhere.com',
  name: 'ben again'
participant5 = new Contact
  email: 'evan@elsewhere.com',
  name: 'EVAN'

describe 'TokenizingTextField', ->
  InboxTestUtils.loadKeymap()

  beforeEach ->
    @completions = []
    @propAdd = jasmine.createSpy 'add'
    @propRemove = jasmine.createSpy 'remove'
    @propEmptied = jasmine.createSpy 'emptied'
    @propTokenKey = jasmine.createSpy("tokenKey").andCallFake (p) -> p.email
    @propTokenNode = (p) -> <CustomToken item={p} />
    @propOnTokenAction = jasmine.createSpy 'tokenAction'
    @propCompletionNode = (p) -> <CustomSuggestion item={p} />
    @propCompletionsForInput = (input) => @completions

    spyOn(@, 'propCompletionNode').andCallThrough()
    spyOn(@, 'propCompletionsForInput').andCallThrough()

    @tabIndex = 100
    @tokens = [participant1, participant2, participant3]

    @renderedField = ReactTestUtils.renderIntoDocument(
      <TokenizingTextField
        tokens={@tokens}
        tokenKey={@propTokenKey}
        tokenNode={@propTokenNode}
        onRequestCompletions={@propCompletionsForInput}
        completionNode={@propCompletionNode}
        onAdd={@propAdd}
        onRemove={@propRemove}
        onEmptied={@propEmptied}
        onTokenAction={@propOnTokenAction}
        tabIndex={@tabIndex}
        />
    )
    @renderedInput = ReactTestUtils.findRenderedDOMComponentWithTag(@renderedField, 'input').getDOMNode()

  it 'renders into the document', ->
    expect(ReactTestUtils.isCompositeComponentWithType @renderedField, TokenizingTextField).toBe(true)

  it 'applies the tabIndex provided to the inner input', ->
    expect(@renderedInput.tabIndex).toBe(@tabIndex)

  it 'shows the tokens provided by the tokenNode method', ->
    @renderedTokens = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomToken)
    expect(@renderedTokens.length).toBe(@tokens.length)

  it 'shows the tokens in the correct order', ->
    @renderedTokens = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomToken)
    for i in [0..@tokens.length-1]
      expect(@renderedTokens[i].props.item).toBe(@tokens[i])

  describe "When the user selects a token", ->
    beforeEach ->
      token = ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'token')[0]
      ReactTestUtils.Simulate.click(token)

    it "should mark the token as focused", ->
      expect(@propTokenKey).toHaveBeenCalledWith(participant1)

    it "should set the selectedTokenKeyState", ->
      expect(@renderedField.state.selectedTokenKey).toBe participant1.email

    it "should return the appropriate token objet", ->
      expect(@renderedField._selectedToken()).toBe participant1

  describe "when focused", ->
    it 'should receive the `focused` class', ->
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(0)
      ReactTestUtils.Simulate.focus(@renderedInput)
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(1)

  describe "when the user types in the input", ->
    it 'should fetch completions for the text', ->
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
      expect(@propCompletionsForInput.calls[0].args[0]).toBe('abc')

    it 'should fetch completions on focus', ->
      @renderedField.setState inputValue: "abc"
      ReactTestUtils.Simulate.focus(@renderedInput)
      expect(@propCompletionsForInput.calls[0].args[0]).toBe('abc')

    it 'should display the completions', ->
      @completions = [participant4, participant5]
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})

      components = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomSuggestion)
      expect(components.length).toBe(2)
      expect(components[0].props.item).toBe(participant4)
      expect(components[1].props.item).toBe(participant5)

    it 'should not display items with keys matching items already in the token field', ->
      @completions = [participant2, participant4, participant1]
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})

      components = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomSuggestion)
      expect(components.length).toBe(1)
      expect(components[0].props.item).toBe(participant4)

    it 'should highlight the first completion', ->
      @completions = [participant4, participant5]
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
      components = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, Menu.Item)
      menuItem = components[0]
      expect(menuItem.props.selected).toBe true

    it 'select the clicked element', ->
      @completions = [participant4, participant5]
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
      components = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, Menu.Item)
      menuItem = components[0]
      ReactTestUtils.Simulate.mouseDown(React.findDOMNode(menuItem))
      expect(@propAdd).toHaveBeenCalledWith([participant4])

  ['enter', ','].forEach (key) ->
    describe "when the user presses #{key}", ->
      describe "and there is an completion available", ->
        it "should call add with the first completion", ->
          @completions = [participant4]
          ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
          InboxTestUtils.keyPress(key, @renderedInput)
          expect(@propAdd).toHaveBeenCalledWith([participant4])

      describe "and there is NO completion available", ->
        it 'should call add, allowing the parent to (optionally) turn the text into a token', ->
          @completions = []
          ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
          InboxTestUtils.keyPress(key, @renderedInput)
          expect(@propAdd).toHaveBeenCalledWith('abc')

  describe "when the user presses tab", ->
    describe "and there is an completion available", ->
      it "should call add with the first completion", ->
        @completions = [participant4]
        ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
        InboxTestUtils.keyPress('tab', @renderedInput)
        expect(@propAdd).toHaveBeenCalledWith([participant4])

  describe "when blurred", ->
    it 'should call add, allowing the parent component to (optionally) turn the entered text into a token', ->
      ReactTestUtils.Simulate.focus(@renderedInput)
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'text'}})
      ReactTestUtils.Simulate.blur(@renderedInput)
      expect(@propAdd).toHaveBeenCalledWith('text')

    it 'should clear the entered text', ->
      ReactTestUtils.Simulate.focus(@renderedInput)
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'text'}})
      ReactTestUtils.Simulate.blur(@renderedInput)
      expect(@renderedInput.value).toBe('')

    it 'should no longer have the `focused` class', ->
      ReactTestUtils.Simulate.focus(@renderedInput)
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(1)
      ReactTestUtils.Simulate.blur(@renderedInput)
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(0)


  describe "When the user removes a token", ->

    it "deletes with the backspace key", ->
      spyOn(@renderedField, "_removeToken")
      InboxTestUtils.keyPress("backspace", @renderedInput)
      expect(@renderedField._removeToken).toHaveBeenCalled()

    describe "when removal is passed in a token object", ->
      it "asks to removes that participant", ->
        @renderedField._removeToken(participant1)
        expect(@propRemove).toHaveBeenCalledWith([participant1])
        expect(@propEmptied).not.toHaveBeenCalled()

    describe "when no token is selected", ->
      it "selects the last token first and doesn't remove", ->
        @renderedField._removeToken()
        expect(@renderedField._selectedToken()).toBe participant3
        expect(@propRemove).not.toHaveBeenCalled()
        expect(@propEmptied).not.toHaveBeenCalled()

    describe "when a token is selected", ->
      beforeEach ->
        @renderedField.setState selectedTokenKey: participant1.email

      it "removes that token and deselects", ->
        @renderedField._removeToken()
        expect(@propRemove).toHaveBeenCalledWith([participant1])
        expect(@renderedField._selectedToken()).toBeUndefined()
        expect(@propEmptied).not.toHaveBeenCalled()

      it "removes on cut when a token is selected", ->
        @renderedField._onCut({preventDefault: -> })
        expect(@propRemove).toHaveBeenCalledWith([participant1])
        expect(@renderedField._selectedToken()).toBeUndefined()
        expect(@propEmptied).not.toHaveBeenCalled()

    describe "when there are no tokens left", ->
      it "fires onEmptied", ->
        newProps = _.clone @renderedField.props
        newProps.tokens = []
        emptyField = ReactTestUtils.renderIntoDocument(
          React.createElement(TokenizingTextField, newProps)
        )
        emptyField._removeToken()
        expect(@propEmptied).toHaveBeenCalled()

