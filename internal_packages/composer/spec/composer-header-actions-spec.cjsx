React = require 'react'
ComposerHeaderActions = require '../lib/composer-header-actions'
Fields = require '../lib/fields'
ReactTestUtils = React.addons.TestUtils
{Actions} = require 'nylas-exports'

describe "ComposerHeaderActions", ->
  makeField = (props = {}) ->
    @onChangeParticipants = jasmine.createSpy("onChangeParticipants")
    @onAdjustEnabledFields = jasmine.createSpy("onAdjustEnabledFields")
    props.onChangeParticipants = @onChangeParticipants
    props.onAdjustEnabledFields = @onAdjustEnabledFields
    props.enabledFields ?= []
    props.draftClientId = 'a'
    @component = ReactTestUtils.renderIntoDocument(
      <ComposerHeaderActions {...props} />
    )

  it "renders all 'show' fields when the focused field is one of the participant fields", ->
    makeField.call(@, {focusedField: Fields.To})
    showCc = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-cc")
    showBcc = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-bcc")
    showSubject = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-subject")
    expect(showCc).toBeDefined()
    expect(showBcc).toBeDefined()
    expect(showSubject).toBeDefined()

  it "does not render the 'show' fields when the focused field is outside the participant fields", ->
    makeField.call(@, {focusedField: Fields.Subject})
    showCc = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-cc")
    showBcc = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-bcc")
    showSubject = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-subject")
    expect(showCc.length).toBe 0
    expect(showBcc.length).toBe 0
    expect(showSubject.length).toBe 0

  it "hides show cc if it's enabled", ->
    makeField.call(@, {focusedField: Fields.To, enabledFields: [Fields.Cc]})
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-cc")
    expect(els.length).toBe 0

  it "hides show bcc if it's enabled", ->
    makeField.call(@, {focusedField: Fields.To, enabledFields: [Fields.Bcc]})
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-bcc")
    expect(els.length).toBe 0

  it "hides show subject if it's enabled", ->
    makeField.call(@, {focusedField: Fields.To, enabledFields: [Fields.Subject]})
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-subject")
    expect(els.length).toBe 0

  it "renders 'popout composer' in the inline mode", ->
    makeField.call(@, {focusedField: Fields.To})
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-popout")
    expect(els.length).toBe 1

  it "doesn't render 'popout composer' if in a composer window", ->
    spyOn(NylasEnv, 'isComposerWindow').andReturn(true)
    makeField.call(@, {focusedField: Fields.To})
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@component, "show-popout")
    expect(els.length).toBe 0

  it "pops out the composer when clicked", ->
    spyOn(Actions, "composePopoutDraft")
    makeField.call(@, {focusedField: Fields.To})
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-popout")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(Actions.composePopoutDraft).toHaveBeenCalled()

  it "shows and focuses cc when clicked", ->
    makeField.call(@, {focusedField: Fields.To})
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-cc")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Cc]

  it "shows and focuses bcc when clicked", ->
    makeField.call(@, {focusedField: Fields.To})
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-bcc")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Bcc]

  it "shows subject when clicked", ->
    makeField.call(@, {focusedField: Fields.To})
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@component, "show-subject")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Subject]
