React = require "react/addons"
ReactTestUtils = React.addons.TestUtils

SendActionButton = require '../lib/send-action-button'
{Actions, Message, ComposerExtension, ExtensionRegistry} = require 'nylas-exports'
{ButtonDropdown, RetinaImg} = require 'nylas-component-kit'

class NAExtension extends ComposerExtension

class GoodExtension extends ComposerExtension
  @sendActionConfig: ({draft}) ->
    title: "Good Extension"
    content: -> <div className="btn-good"></div>
    onSend: ->

class SecondExtension extends ComposerExtension
  @sendActionConfig: ({draft}) ->
    title: "Second Extension"
    content: -> <div className="btn-second"></div>
    onSend: ->

class NullExtension extends ComposerExtension
  @sendActionConfig: ({draft}) -> null

isValidDraft = null

describe "SendActionButton", ->
  render = (draft, valid=true) ->
    isValidDraft = jasmine.createSpy("isValidDraft").andReturn(valid)

    ReactTestUtils.renderIntoDocument(
      <SendActionButton draft={draft} isValidDraft={isValidDraft} />
    )

  beforeEach ->
    spyOn(NylasEnv, "reportError")
    spyOn(Actions, "sendDraft")
    @clientId = "client-23"
    @draft = new Message(clientId: @clientId, draft: true)

  it "renders without error", ->
    @sendActionButton = render(@draft)
    expect(ReactTestUtils.isCompositeComponentWithType @sendActionButton, SendActionButton).toBe true

  it "is a single button when there are no extensions", ->
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn []
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 1
    expect(dropdowns.length).toBe 0

  it "is a dropdown when there's another valid extension", ->
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [GoodExtension]
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 0
    expect(dropdowns.length).toBe 1

  it "has the correct primary item", ->
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [GoodExtension, SecondExtension]
    spyOn(NylasEnv.config, 'get').andReturn('second-extension')
    @sendActionButton = render(@draft)
    dropdown = ReactTestUtils.findRenderedComponentWithType(@sendActionButton, ButtonDropdown)
    expect(dropdown.props.primaryTitle).toBe "Second Extension"

  it "falls back to a default if the primary item can't be found", ->
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [GoodExtension, SecondExtension]
    spyOn(NylasEnv.config, 'get').andReturn('does-not-exist')
    @sendActionButton = render(@draft)
    dropdown = ReactTestUtils.findRenderedComponentWithType(@sendActionButton, ButtonDropdown)
    expect(dropdown.props.primaryTitle).toBe "Send"

  it "is a single button when a valid extension returns null", ->
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [NullExtension]
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 1
    expect(dropdowns.length).toBe 0

  it "still renders but catches when an extension is missing a title", ->
    class NoTitle extends ComposerExtension
      @sendActionConfig: ({draft}) ->
        title: null
        iconUrl: "nylas://foo/bar/baz"
        onSend: ->

    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [NoTitle]
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 1
    expect(dropdowns.length).toBe 0
    expect(NylasEnv.reportError).toHaveBeenCalled()
    expect(NylasEnv.reportError.calls[0].args[0].message).toMatch /title/

  it "still renders with a null iconUrl and doesn't show the image", ->
    class NoIconUrl extends ComposerExtension
      @sendActionConfig: ({draft}) ->
        title: "some title"
        iconUrl: null
        onSend: ->

    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [NoIconUrl]
    spyOn(NylasEnv.config, 'get').andReturn('some-title')
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    icons = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, RetinaImg)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 0 # It's a dropdown instead
    expect(dropdowns.length).toBe 1
    expect(icons.length).toBe 3

  it "still renders but catches when an extension is missing an onSend", ->
    class NoClick extends ComposerExtension
      @sendActionConfig: ({draft}) ->
        title: "some title"
        iconUrl: "nylas://foo/bar/baz"
        onSend: null

    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [NoClick]
    @sendActionButton = render(@draft)
    dropdowns = ReactTestUtils.scryRenderedComponentsWithType(@sendActionButton, ButtonDropdown)
    buttons = ReactTestUtils.scryRenderedDOMComponentsWithTag(@sendActionButton, "button")
    expect(buttons.length).toBe 1
    expect(dropdowns.length).toBe 0
    expect(NylasEnv.reportError).toHaveBeenCalled()
    expect(NylasEnv.reportError.calls[0].args[0].message).toMatch /onSend/

  it "sends a draft by default", ->
    @sendActionButton = render(@draft)
    button = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithTag(@sendActionButton, "button"))
    ReactTestUtils.Simulate.click(button)
    expect(isValidDraft).toHaveBeenCalled()
    expect(Actions.sendDraft).toHaveBeenCalled()
    expect(Actions.sendDraft.calls[0].args[0]).toBe @draft.clientId

  it "doesn't send a draft if the isValidDraft fails", ->
    @sendActionButton = render(@draft, false)
    button = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithTag(@sendActionButton, "button"))
    ReactTestUtils.Simulate.click(button)
    expect(isValidDraft).toHaveBeenCalled()
    expect(Actions.sendDraft).not.toHaveBeenCalled()

  it "does the primaryClick action of the extension", ->
    clicked = false
    class Click extends ComposerExtension
      @sendActionConfig: ({draft}) ->
        title: "click"
        iconUrl: "nylas://foo/bar/baz"
        onSend: -> clicked = "onSend fired"
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [Click]
    spyOn(NylasEnv.config, 'get').andReturn('click')

    @sendActionButton = render(@draft)

    button = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(@sendActionButton, "primary-item"))
    ReactTestUtils.Simulate.click(button)
    expect(clicked).toBe "onSend fired"

  it "catches any errors in an extension's primaryClick method", ->
    clicked = false
    class Click extends ComposerExtension
      @sendActionConfig: ({draft}) ->
        title: "click"
        iconUrl: "nylas://foo/bar/baz"
        onSend: -> throw new Error("BOO")
    spyOn(ExtensionRegistry.Composer, "extensions").andReturn [Click]
    spyOn(NylasEnv.config, 'get').andReturn('click')

    @sendActionButton = render(@draft)

    button = React.findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(@sendActionButton, "primary-item"))
    ReactTestUtils.Simulate.click(button)
    expect(clicked).toBe false
    expect(NylasEnv.reportError).toHaveBeenCalled()
    expect(NylasEnv.reportError.calls[0].args[0].message).toMatch /BOO/

  it "initializes with the default and shows the standard Send option", ->
    spyOn(NylasEnv.config, 'get').andReturn(null)
    @sendActionButton = render(@draft)
    button = React.findDOMNode(@sendActionButton)
    expect(button.innerText).toEqual('Send')
