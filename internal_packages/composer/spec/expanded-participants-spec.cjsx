_ = require "underscore"
React = require "react/addons"
Fields = require '../lib/fields'
ReactTestUtils = React.addons.TestUtils
AccountContactField = require '../lib/account-contact-field'
ExpandedParticipants = require '../lib/expanded-participants'
{Actions} = require 'nylas-exports'

describe "ExpandedParticipants", ->
  makeField = (props={}) ->
    @onChangeParticipants = jasmine.createSpy("onChangeParticipants")
    @onAdjustEnabledFields = jasmine.createSpy("onAdjustEnabledFields")
    props.onChangeParticipants = @onChangeParticipants
    props.onAdjustEnabledFields = @onAdjustEnabledFields
    @fields = ReactTestUtils.renderIntoDocument(
      <ExpandedParticipants {...props} />
    )

  it "always renders to field", ->
    makeField.call(@)
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "to-field")
    expect(el).toBeDefined()

  it "renders cc when enabled", ->
    makeField.call(@, enabledFields: [Fields.Cc])
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "cc-field")
    expect(el).toBeDefined()

  it "renders bcc when enabled", ->
    makeField.call(@, enabledFields: [Fields.Bcc])
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "bcc-field")
    expect(el).toBeDefined()

  it "renders from when enabled", ->
    makeField.call(@, enabledFields: [Fields.From])
    el = ReactTestUtils.findRenderedComponentWithType(@fields, AccountContactField)
    expect(el).toBeDefined()

  it "renders all 'show' fields", ->
    makeField.call(@)
    showCc = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-cc")
    showBcc = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-bcc")
    showSubject = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-subject")
    expect(showCc).toBeDefined()
    expect(showBcc).toBeDefined()
    expect(showSubject).toBeDefined()

  it "hides show cc if it's enabled", ->
    makeField.call(@, enabledFields: [Fields.Cc])
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "show-cc")
    expect(els.length).toBe 0

  it "hides show bcc if it's enabled", ->
    makeField.call(@, enabledFields: [Fields.Bcc])
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "show-bcc")
    expect(els.length).toBe 0

  it "hides show subject if it's enabled", ->
    makeField.call(@, enabledFields: [Fields.Subject])
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "show-subject")
    expect(els.length).toBe 0

  it "renders popout composer in the inline mode", ->
    makeField.call(@, mode: "inline")
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "show-popout")
    expect(els.length).toBe 1

  it "doesn't render popout composer in the fullwindow mode", ->
    makeField.call(@, mode: "fullwindow")
    els = ReactTestUtils.scryRenderedDOMComponentsWithClass(@fields, "show-popout")
    expect(els.length).toBe 0

  it "pops out the composer when clicked", ->
    spyOn(Actions, "composePopoutDraft")
    onPopoutComposer = jasmine.createSpy('onPopoutComposer')
    makeField.call(@, mode: "inline", onPopoutComposer: onPopoutComposer)
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-popout")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(onPopoutComposer).toHaveBeenCalled()
    expect(onPopoutComposer.calls.length).toBe 1

  it "shows and focuses cc when clicked", ->
    makeField.call(@)
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-cc")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Cc]

  it "shows and focuses bcc when clicked", ->
    makeField.call(@)
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-bcc")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Bcc]

  it "shows subject when clicked", ->
    makeField.call(@)
    el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "show-subject")
    ReactTestUtils.Simulate.click(React.findDOMNode(el))
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith show: [Fields.Subject]

  it "empties cc and focuses on to field", ->
    makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
    @fields.refs[Fields.Cc].props.onEmptied()
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Cc]

  it "empties bcc and focuses on to field", ->
    makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
    @fields.refs[Fields.Bcc].props.onEmptied()
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Bcc]

  it "empties bcc and focuses on cc field", ->
    makeField.call(@, enabledFields: [Fields.Bcc, Fields.Subject])
    @fields.refs[Fields.Bcc].props.onEmptied()
    expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Bcc]

  it "notifies when participants change", ->
    makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
    @fields.refs[Fields.Cc].props.change()
    expect(@onChangeParticipants).toHaveBeenCalled()
