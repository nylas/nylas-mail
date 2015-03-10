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
    @propTokenKey = (p) -> p.email
    @propTokenContent = (p) -> <CustomToken item={p} />
    @propCompletionsForInput = (input) => @completions
    @propCompletionContent = (p) -> <CustomSuggestion item={p} />

    spyOn(@, 'propCompletionContent').andCallThrough()
    spyOn(@, 'propCompletionsForInput').andCallThrough()

    @fieldName = 'to'
    @tabIndex = 100
    @tokens = [participant1, participant2, participant3]

    @renderedField = ReactTestUtils.renderIntoDocument(
      <TokenizingTextField
        name={@fieldName}
        tabIndex={@tabIndex}
        tokens={@tokens}
        tokenKey={@propTokenKey}
        tokenContent={@propTokenContent}
        completionsForInput={@propCompletionsForInput}
        completionContent={@propCompletionContent}
        add={@propAdd}
        remove={@propRemove} />
    )
    @renderedInput = ReactTestUtils.findRenderedDOMComponentWithTag(@renderedField, 'input').getDOMNode()

  it 'renders into the document', ->
    expect(ReactTestUtils.isCompositeComponentWithType @renderedField, TokenizingTextField).toBe(true)

  it 'applies the tabIndex provided to the inner input', ->
    expect(@renderedInput.tabIndex).toBe(@tabIndex)

  it 'shows the tokens provided by the tokenContent method', ->
    @renderedTokens = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomToken)
    expect(@renderedTokens.length).toBe(@tokens.length)

  it 'shows the tokens in the correct order', ->
    @renderedTokens = ReactTestUtils.scryRenderedComponentsWithType(@renderedField, CustomToken)
    for i in [0..@tokens.length-1]
      expect(@renderedTokens[i].props.item).toBe(@tokens[i])

  describe "when focused", ->
    it 'should receive the `focused` class', ->
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(0)
      ReactTestUtils.Simulate.focus(@renderedInput)
      expect(ReactTestUtils.scryRenderedDOMComponentsWithClass(@renderedField, 'focused').length).toBe(1)

  describe "when the user types in the input", ->
    it 'should fetch completions for the text', ->
      ReactTestUtils.Simulate.change(@renderedInput, {target: {value: 'abc'}})
      expect(@propCompletionsForInput).toHaveBeenCalledWith('abc')

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
      ReactTestUtils.Simulate.mouseDown(menuItem.getDOMNode())
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
          expect(@propAdd).toHaveBeenCalledWith(['abc'])

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
      expect(@propAdd).toHaveBeenCalledWith(['text'])

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

