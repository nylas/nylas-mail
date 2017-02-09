_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
{mount} = require 'enzyme'


{NylasTestUtils,
 Account,
 AccountStore,
 Contact,
} = require 'nylas-exports'
{TokenizingTextField, Menu} = require 'nylas-component-kit'

CustomToken = React.createClass
  render: ->
    <span>{@props.token.email}</span>

CustomSuggestion = React.createClass
  render: ->
    <span>{@props.item.email}</span>

participant1 = new Contact
  id: '1'
  email: 'ben@nylas.com'
  isSearchIndexed: false
participant2 = new Contact
  id: '2'
  email: 'burgers@nylas.com'
  name: 'Nylas Burger Basket'
  isSearchIndexed: false
participant3 = new Contact
  id: '3'
  email: 'evan@nylas.com'
  name: 'Evan'
  isSearchIndexed: false
participant4 = new Contact
  id: '4'
  email: 'tester@elsewhere.com',
  name: 'Tester'
  isSearchIndexed: false
participant5 = new Contact
  id: '5'
  email: 'michael@elsewhere.com',
  name: 'Michael'
  isSearchIndexed: false

describe 'TokenizingTextField', ->
  beforeEach ->
    @completions = []
    @propAdd = jasmine.createSpy 'add'
    @propEdit = jasmine.createSpy 'edit'
    @propRemove = jasmine.createSpy 'remove'
    @propEmptied = jasmine.createSpy 'emptied'
    @propTokenKey = jasmine.createSpy("tokenKey").andCallFake (p) -> p.email
    @propTokenIsValid = jasmine.createSpy("tokenIsValid").andReturn(true)
    @propTokenRenderer = CustomToken
    @propOnTokenAction = jasmine.createSpy 'tokenAction'
    @propCompletionNode = (p) -> <CustomSuggestion item={p} />
    @propCompletionsForInput = (input) => @completions

    spyOn(@, 'propCompletionNode').andCallThrough()
    spyOn(@, 'propCompletionsForInput').andCallThrough()

    @tokens = [participant1, participant2, participant3]

    @rebuildRenderedField = (tokens) =>
      tokens ?= @tokens
      @renderedField = mount(
        <TokenizingTextField
          tokens={@tokens}
          tokenKey={@propTokenKey}
          tokenRenderer={@propTokenRenderer}
          tokenIsValid={@propTokenIsValid}
          onRequestCompletions={@propCompletionsForInput}
          completionNode={@propCompletionNode}
          onAdd={@propAdd}
          onEdit={@propEdit}
          onRemove={@propRemove}
          onEmptied={@propEmptied}
          onTokenAction={@propOnTokenAction}
          tabIndex={@tabIndex}
          />
      )
      @renderedInput = @renderedField.find('input')
      return @renderedField

    @rebuildRenderedField()

  it 'renders into the document', ->
    expect(@renderedField.find(TokenizingTextField).length).toBe(1)

  it 'should render an input field', ->
    expect(@renderedInput).toBeDefined()

  it 'shows the tokens provided by the tokenRenderer', ->
    expect(@renderedField.find(CustomToken).length).toBe(@tokens.length)

  it 'shows the tokens in the correct order', ->
    @renderedTokens = @renderedField.find(CustomToken)
    for i in [0..@tokens.length-1]
      expect(@renderedTokens.at(i).props().token).toBe(@tokens[i])

  describe "prop: tokenIsValid", ->
    it "should be evaluated for each token when it's provided", ->
      @propTokenIsValid = jasmine.createSpy("tokenIsValid").andCallFake (p) =>
        if p is participant2 then true else false

      @rebuildRenderedField()
      @tokens = @renderedField.find(TokenizingTextField.Token)
      expect(@tokens.at(0).props().valid).toBe(false)
      expect(@tokens.at(1).props().valid).toBe(true)
      expect(@tokens.at(2).props().valid).toBe(false)

    it "should default to true when not provided", ->
      @propTokenIsValid = null
      @rebuildRenderedField()
      @tokens = @renderedField.find(TokenizingTextField.Token)
      expect(@tokens.at(0).props().valid).toBe(true)
      expect(@tokens.at(1).props().valid).toBe(true)
      expect(@tokens.at(2).props().valid).toBe(true)

  describe "when the user drags and drops a token between two fields", ->
    it "should work properly", ->
      participant2.clientId = '123'

      tokensA = [participant1, participant2, participant3]
      fieldA = @rebuildRenderedField(tokensA)

      tokensB = []
      fieldB = @rebuildRenderedField(tokensB)

      tokenIndexToDrag = 1
      token = fieldA.find('.token').at(tokenIndexToDrag)

      dragStartEventData = {}
      dragStartEvent =
        dataTransfer:
          setData: (type, val) ->
            dragStartEventData[type] = val
      token.simulate('dragStart', dragStartEvent)

      expect(dragStartEventData).toEqual({
        'nylas-token-items': '[{"client_id":"123","server_id":"2","name":"Nylas Burger Basket","email":"burgers@nylas.com","thirdPartyData":{},"is_search_indexed":false,"id":"2","__constructorName":"Contact"}]'
        'text/plain': 'Nylas Burger Basket <burgers@nylas.com>'
      })

      dropEvent =
        dataTransfer:
          types: Object.keys(dragStartEventData)
          getData: (type) -> dragStartEventData[type]

      fieldB.ref('field-drop-target').simulate('drop', dropEvent)

      expect(@propAdd).toHaveBeenCalledWith([tokensA[tokenIndexToDrag]])

  describe "When the user selects a token", ->
    beforeEach ->
      token = @renderedField.find('.token').first()
      token.simulate('click')

    it "should set the selectedKeys state", ->
      expect(@renderedField.state().selectedKeys).toEqual([participant1.email])

    it "should return the appropriate token object", ->
      expect(@propTokenKey).toHaveBeenCalledWith(participant1)
      expect(@renderedField.find('.token.selected').length).toEqual(1)

  describe "when focused", ->
    it 'should receive the `focused` class', ->
      expect(@renderedField.find('.focused').length).toBe(0)
      @renderedInput.simulate('focus')
      expect(@renderedField.find('.focused').length).toBe(1)

  describe "when the user types in the input", ->
    it 'should fetch completions for the text', ->
      @renderedInput.simulate('change', {target: {value: 'abc'}})
      advanceClock(1000)
      expect(@propCompletionsForInput.calls[0].args[0]).toBe('abc')

    it 'should fetch completions on focus', ->
      @renderedField.setState({inputValue: "abc"})
      @renderedInput.simulate('focus')
      advanceClock(1000)
      expect(@propCompletionsForInput.calls[0].args[0]).toBe('abc')

    it 'should display the completions', ->
      @completions = [participant4, participant5]
      @renderedInput.simulate('change', {target: {value: 'abc'}})

      components = @renderedField.find(CustomSuggestion)
      expect(components.length).toBe(2)
      expect(components.at(0).props().item).toBe(participant4)
      expect(components.at(1).props().item).toBe(participant5)

    it 'should not display items with keys matching items already in the token field', ->
      @completions = [participant2, participant4, participant1]
      @renderedInput.simulate('change', {target: {value: 'abc'}})

      components = @renderedField.find(CustomSuggestion)
      expect(components.length).toBe(1)
      expect(components.at(0).props().item).toBe(participant4)

    it 'should highlight the first completion', ->
      @completions = [participant4, participant5]
      @renderedInput.simulate('change', {target: {value: 'abc'}})
      components = @renderedField.find(Menu.Item)
      menuItem = components.first()
      expect(menuItem.props().selected).toBe true

    it 'select the clicked element', ->
      @completions = [participant4, participant5]
      @renderedInput.simulate('change', {target: {value: 'abc'}})
      components = @renderedField.find(Menu.Item)
      menuItem = components.first()
      menuItem.simulate('mouseDown')
      expect(@propAdd).toHaveBeenCalledWith([participant4])

    it "doesn't sumbmit if it looks like an email but has no space at the end", ->
      @renderedInput.simulate('change', {target: {value: 'abc@foo.com'}})
      advanceClock(10)
      expect(@propCompletionsForInput.calls[0].args[0]).toBe('abc@foo.com')
      expect(@propAdd).not.toHaveBeenCalled()

    it "allows spaces if what's currently being entered doesn't look like an email", ->
      @renderedInput.simulate('change', {target: {value: 'ab'}})
      advanceClock(10)
      @renderedInput.simulate('change', {target: {value: 'ab '}})
      advanceClock(10)
      @renderedInput.simulate('change', {target: {value: 'ab c'}})
      advanceClock(10)
      expect(@propCompletionsForInput.calls[2].args[0]).toBe('ab c')
      expect(@propAdd).not.toHaveBeenCalled()

  [{key:'Enter', keyCode:13}, {key:',', keyCode: 188}].forEach ({key, keyCode}) ->
    describe "when the user presses #{key}", ->
      describe "and there is an completion available", ->
        it "should call add with the first completion", ->
          @completions = [participant4]
          @renderedInput.simulate('change', {target: {value: 'abc'}})
          @renderedInput.simulate('keyDown', {key: key, keyCode: keyCode})
          expect(@propAdd).toHaveBeenCalledWith([participant4])

      describe "and there is NO completion available", ->
        it 'should call add, allowing the parent to (optionally) turn the text into a token', ->
          @completions = []
          @renderedInput.simulate('change', {target: {value: 'abc'}})
          @renderedInput.simulate('keyDown', {key: key, keyCode: keyCode})
          expect(@propAdd).toHaveBeenCalledWith('abc', {})

  describe "when the user presses tab", ->
    beforeEach ->
      @tabDownEvent =
        key: "Tab"
        keyCode: 9
        preventDefault: jasmine.createSpy('preventDefault')
        stopPropagation: jasmine.createSpy('stopPropagation')

    describe "and there is an completion available", ->
      it "should call add with the first completion", ->
        @completions = [participant4]
        @renderedInput.simulate('change', {target: {value: 'abc'}})
        @renderedInput.simulate('keyDown', @tabDownEvent)
        expect(@propAdd).toHaveBeenCalledWith([participant4])
        expect(@tabDownEvent.preventDefault).toHaveBeenCalled()
        expect(@tabDownEvent.stopPropagation).toHaveBeenCalled()

    it "shouldn't handle the event in the input is empty", ->
      # We ignore on empty input values
      @renderedInput.simulate('change', {target: {value: ' '}})
      @renderedInput.simulate('keyDown', @tabDownEvent)
      expect(@propAdd).not.toHaveBeenCalled()

    it "should NOT stop the propagation if the input is empty.", ->
      # This is to allow tabs to propagate up to controls that might want
      # to change the focus later.
      @renderedInput.simulate('change', {target: {value: ' '}})
      @renderedInput.simulate('keyDown', @tabDownEvent)
      expect(@propAdd).not.toHaveBeenCalled()
      expect(@tabDownEvent.stopPropagation).not.toHaveBeenCalled()

    it "should add the raw input value if there are no completions", ->
      @completions = []
      @renderedInput.simulate('change', {target: {value: 'abc'}})
      @renderedInput.simulate('keyDown', @tabDownEvent)
      expect(@propAdd).toHaveBeenCalledWith('abc', {})
      expect(@tabDownEvent.preventDefault).toHaveBeenCalled()
      expect(@tabDownEvent.stopPropagation).toHaveBeenCalled()

  describe "when blurred", ->
    it 'should do nothing if the relatedTarget is null meaning the app has been blurred', ->
      @renderedInput.simulate('focus')
      @renderedInput.simulate('change', {target: {value: 'text'}})
      @renderedInput.simulate('blur', {relatedTarget: null})
      expect(@propAdd).not.toHaveBeenCalled()
      expect(@renderedField.find('.focused').length).toBe(1)

    it 'should call add, allowing the parent component to (optionally) turn the entered text into a token', ->
      @renderedInput.simulate('focus')
      @renderedInput.simulate('change', {target: {value: 'text'}})
      @renderedInput.simulate('blur', {relatedTarget: document.body})
      expect(@propAdd).toHaveBeenCalledWith('text', {})

    it 'should clear the entered text', ->
      @renderedInput.simulate('focus')
      @renderedInput.simulate('change', {target: {value: 'text'}})
      @renderedInput.simulate('blur', {relatedTarget: document.body})
      expect(@renderedInput.props().value).toBe('')

    it 'should no longer have the `focused` class', ->
      @renderedInput.simulate('focus')
      expect(@renderedField.find('.focused').length).toBe(1)
      @renderedInput.simulate('blur', {relatedTarget: document.body})
      expect(@renderedField.find('.focused').length).toBe(0)

  describe "cut", ->
    it "removes the selected tokens", ->
      @renderedField.setState({selectedKeys: [participant1.email]})
      @renderedInput.simulate('cut')
      expect(@propRemove).toHaveBeenCalledWith([participant1])
      expect(@renderedField.find('.token.selected').length).toEqual(0)
      expect(@propEmptied).not.toHaveBeenCalled()

  describe "backspace", ->
    describe "when no token is selected", ->
      it "selects the last token first and doesn't remove", ->
        @renderedInput.simulate('keyDown', {key: 'Backspace', keyCode: 8})
        expect(@renderedField.find('.token.selected').length).toEqual(1)
        expect(@propRemove).not.toHaveBeenCalled()
        expect(@propEmptied).not.toHaveBeenCalled()

    describe "when a token is selected", ->
      it "removes that token and deselects", ->
        @renderedField.setState({selectedKeys: [participant1.email]})
        expect(@renderedField.find('.token.selected').length).toEqual(1)
        @renderedInput.simulate('keyDown', {key: 'Backspace', keyCode: 8})
        expect(@propRemove).toHaveBeenCalledWith([participant1])
        expect(@renderedField.find('.token.selected').length).toEqual(0)
        expect(@propEmptied).not.toHaveBeenCalled()

    describe "when there are no tokens left", ->
      it "fires onEmptied", ->
        @renderedField.setProps({tokens: []})
        expect(@renderedField.find('.token').length).toEqual(0)
        @renderedInput.simulate('keyDown', {key: 'Backspace', keyCode: 8})
        expect(@propEmptied).toHaveBeenCalled()

describe "TokenizingTextField.Token", ->
  describe "when an onEdit prop has been provided", ->
    beforeEach ->
      @propEdit = jasmine.createSpy('onEdit')
      @propClick = jasmine.createSpy('onClick')
      @token = mount(React.createElement(TokenizingTextField.Token, {
        selected: false,
        valid: true,
        item: participant1,
        onClick: @propClick,
        onEdited: @propEdit,
        onDragStart: jasmine.createSpy('onDragStart'),
      }))

    it "should enter editing mode", ->
      expect(@token.state().editing).toBe(false)
      @token.simulate('doubleClick', {})
      expect(@token.state().editing).toBe(true)

    it "should call onEdit to commit the new token value when the edit field is blurred", ->
      expect(@token.state().editing).toBe(false)
      @token.simulate('doubleClick', {})
      tokenEditInput = @token.find('input')
      tokenEditInput.simulate('change', {target: {value: 'new tag content'}})
      tokenEditInput.simulate('blur')
      expect(@propEdit).toHaveBeenCalledWith(participant1, 'new tag content')

  describe "when no onEdit prop has been provided", ->
    it "should not enter editing mode", ->
      @token = mount(React.createElement(TokenizingTextField.Token, {
        selected: false,
        valid: true,
        item: participant1,
        onClick: jasmine.createSpy('onClick'),
        onDragStart: jasmine.createSpy('onDragStart'),
        onEdited: null,
      }))
      expect(@token.state().editing).toBe(false)
      @token.simulate('doubleClick', {})
      expect(@token.state().editing).toBe(false)
