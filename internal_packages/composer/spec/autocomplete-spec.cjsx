_ = require 'underscore-plus'
CSON = require 'season'
React = require 'react/addons'
ReactTestUtils = React.addons.TestUtils

ComposerParticipants = require '../lib/composer-participants.cjsx'
ComposerParticipant = require '../lib/composer-participant.cjsx'

{InboxTestUtils,
 Namespace,
 NamespaceStore,
 Contact,
 ContactStore,
} = require 'inbox-exports'

me = new Namespace
  name: 'Test User'
  email: 'test@example.com'
  provider: 'inbox'
NamespaceStore._current = me

participant1 = new Contact
  email: 'zip@inboxapp.com'
participant2 = new Contact
  email: 'zip@example.com'
  name: 'zip'
participant3 = new Contact
  email: 'zip@inboxapp.com'
  name: 'Duplicate email'
participant4 = new Contact
  email: 'zip@elsewhere.com',
  name: 'zip again'

default_participants = [participant1, participant2]
all_participants = [participant1, participant2, participant3, participant4]

describe 'Autocomplete', ->
  keymap_path = 'internal_packages/composer/keymaps/composer.cson'
  keymap_file = CSON.readFileSync keymap_path
  # We have to add these manually for testing

  beforeEach ->
    @onAdd = jasmine.createSpy 'add'
    @onRemove = jasmine.createSpy 'remove'
    @participants = ReactTestUtils.renderIntoDocument(
      <ComposerParticipants
        participants={default_participants}
        participantFunctions={{
        add: @onAdd
        remove: @onRemove
        }}
      />
    )
    @renderedParticipants = ReactTestUtils.scryRenderedComponentsWithType @participants, ComposerParticipant

  it 'renders into the document', ->
    expect(ReactTestUtils.isCompositeComponentWithType @participants, ComposerParticipants).toBe true

  it 'shows the participants by default', ->
    expect(@renderedParticipants.length).toBe(2)

  it 'should render the participants specified', ->
    expect(@renderedParticipants[0].props.participant).toEqual participant1
    expect(@renderedParticipants[1].props.participant).toEqual participant2

  it 'fires onRemove with a participant when the "x" is clicked', ->
    button = @renderedParticipants[0].getDOMNode().querySelector('i')
    expect(button).toBeDefined()
    ReactTestUtils.Simulate.click(button)
    expect(@onRemove).toHaveBeenCalledWith(participant1)

  it 'should have one element with a "hasName" class', ->
    hasname = ReactTestUtils.scryRenderedDOMComponentsWithClass(@participants, 'hasName')
    expect(hasname.length).toBe(1)

  describe 'the input', ->
    beforeEach ->
      atom.keymaps.add keymap_path, keymap_file
      @input = @participants.refs.autocomplete.getDOMNode()

    it 'should remove the last participant when "backspace" is pressed', ->
      @input.focus()
      ReactTestUtils.Simulate.focus(@input)
      InboxTestUtils.keyPress 'backspace', @input
      expect(@onRemove).toHaveBeenCalledWith(participant2)

    it 'should not call @onRemove with no participants', ->
      onRemove = jasmine.createSpy 'remove'
      participants = ReactTestUtils.renderIntoDocument(
        <ComposerParticipants
          participants={[]}
          onRemove={onRemove}
        />
      )
      input = participants.refs.autocomplete.getDOMNode()
      InboxTestUtils.keyPress 'backspace', input
      expect(onRemove).not.toHaveBeenCalled()

    it 'should not bring up an autocomplete box for no input', ->
      spyOn(ContactStore, 'searchContacts')
      ReactTestUtils.Simulate.focus(@input)
      expect(ContactStore.searchContacts).not.toHaveBeenCalled()
      completions = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, 'completions')
      expect(completions.getDOMNode().style.display).toBe 'none'

    it 'should do nothing on "tab"', ->
      spyOn(@participants, "_addParticipant").andCallThrough()
      InboxTestUtils.keyPress('tab', @input)
      expect(@participants._addParticipant).not.toHaveBeenCalled()

    it 'should do nothing on "blur"', ->
      spyOn(@participants, "_addParticipant").andCallThrough()
      @input.focus()
      ReactTestUtils.Simulate.focus(@input)
      @input.blur()
      ReactTestUtils.Simulate.blur(@input)
      expect(@participants._addParticipant).not.toHaveBeenCalled()

    it 'should remove the last participant when "backspace" is pressed', ->
      @input.focus()
      ReactTestUtils.Simulate.focus(@input)
      InboxTestUtils.keyPress 'backspace', @input
      expect(@onRemove).toHaveBeenCalledWith(participant2)

    it 'should do nothing when escape is pushed', ->
      spyOn(@participants, "_addParticipant").andCallThrough()
      @input.focus()
      ReactTestUtils.Simulate.focus(@input)
      InboxTestUtils.keyPress('escape', @input)
      expect(@participants._addParticipant).not.toHaveBeenCalled()

    describe 'when typing an email with no suggestions', ->
      beforeEach ->
        spyOn(@participants, "_addParticipant").andCallThrough()
        @input.focus()
        ReactTestUtils.Simulate.focus(@input)
        @input.value = participant4.email
        ReactTestUtils.Simulate.change(@input)

      it 'has the right class', ->
        nodes = ReactTestUtils.scryRenderedDOMComponentsWithClass(@participants, "autocomplete-no-suggestions")
        expect(nodes.length).toBe 1

      it 'should complete on "tab"', ->
        InboxTestUtils.keyPress('tab', @input)
        addedEmail = @participants._addParticipant.calls[0].args[0].email
        expect(addedEmail).toEqual participant4.email
        expect(@participants.state.currentEmail).toBe ''

      it 'should complete on "enter"', ->
        InboxTestUtils.keyPress('enter', @input)
        addedEmail = @participants._addParticipant.calls[0].args[0].email
        expect(addedEmail).toEqual participant4.email
        expect(@participants.state.currentEmail).toBe ''

      it 'should complete on "comma"', ->
        InboxTestUtils.keyPress(',', @input)
        addedEmail = @participants._addParticipant.calls[0].args[0].email
        expect(addedEmail).toEqual participant4.email
        expect(@participants.state.currentEmail).toBe ''

      it 'should complete on "space"', ->
        InboxTestUtils.keyPress('space', @input)
        addedEmail = @participants._addParticipant.calls[0].args[0].email
        expect(addedEmail).toEqual participant4.email
        expect(@participants.state.currentEmail).toBe ''

      it 'should complete on "blur"', ->
        @input.blur()
        ReactTestUtils.Simulate.blur(@input)
        addedEmail = @participants._addParticipant.calls[0].args[0].email
        expect(addedEmail).toEqual participant4.email
        expect(@participants.state.currentEmail).toBe ''

      it 'should clear the suggestion without adding when escape is pushed', ->
        InboxTestUtils.keyPress('escape', @input)
        expect(@participants._addParticipant).not.toHaveBeenCalled()
        expect(@participants.state.currentEmail).toBe ''

    describe 'when typing a name with no suggestions', ->
      beforeEach ->
        spyOn(@participants, "_addParticipant").andCallThrough()
        @input.focus()
        ReactTestUtils.Simulate.focus(@input)
        @input.value = "Foobar"
        ReactTestUtils.Simulate.change(@input)

      it 'should NOT complete on "space"', ->
        InboxTestUtils.keyPress('space', @input)
        expect(@participants._addParticipant).not.toHaveBeenCalled()

      it 'should do nothing on "blur"', ->
        @input.focus()
        ReactTestUtils.Simulate.focus(@input)
        @input.blur()
        ReactTestUtils.Simulate.blur(@input)
        expect(@participants._addParticipant).not.toHaveBeenCalled()

    describe 'in autocomplete mode', ->
      beforeEach ->
        spyOn(ContactStore, 'searchContacts').andReturn(all_participants)
        spyOn(@participants, "_addParticipant").andCallThrough()
        @input.focus()
        ReactTestUtils.Simulate.focus(@input)
        @input.value = 'z'
        ReactTestUtils.Simulate.change(@input)
        @completions = ReactTestUtils.findRenderedDOMComponentWithClass(@participants, 'completions')

      it 'should clear the suggestion without adding when escape is pushed', ->
        InboxTestUtils.keyPress('escape', @input)
        expect(@participants._addParticipant).not.toHaveBeenCalled()
        expect(@participants.state.currentEmail).toBe ''

      it 'should query the contact store for input', ->
        expect(ContactStore.searchContacts).toHaveBeenCalledWith('z')

      it 'should show the completions field', ->
        expect(@completions.getDOMNode().style.display).toBe 'initial'
        expect(ReactTestUtils.scryRenderedComponentsWithType(@completions, ComposerParticipant).length).toBe all_participants.length

      it 'should hide the completions field on blur', ->
        @input.blur()
        ReactTestUtils.Simulate.blur(@input)
        expect(@completions.getDOMNode().style.display).toBe 'none'
        expect(ReactTestUtils.scryRenderedComponentsWithType(@completions, ComposerParticipant).length).toBe all_participants.length
        expect(@participants.state.selectedIndex).toBe 0

      it 'should not fire when clicking an existing email in its field', ->
        ReactTestUtils.Simulate.mouseUp(@completions.getDOMNode().querySelectorAll('li')[0])
        expect(@onAdd).not.toHaveBeenCalled()

      it 'should fire for a new email address which has been clicked', ->
        ReactTestUtils.Simulate.mouseUp(@completions.getDOMNode().querySelectorAll('li')[3])
        expect(@onAdd).toHaveBeenCalledWith(participant4)

      it 'should start with an index of 0', ->
        expect(@participants.state.selectedIndex).toEqual 1

      it 'should increment the index when "down" is pressed', ->
        InboxTestUtils.keyPress 'down', @input
        expect(@participants.state.selectedIndex).toEqual 2

      it 'should decrement the index and wrap when "up" is pressed', ->
        InboxTestUtils.keyPress 'up', @input
        expect(@participants.state.selectedIndex).toEqual all_participants.length

      it 'should wrap when the end is reached', ->
        InboxTestUtils.keyPress 'down', @input
        InboxTestUtils.keyPress 'down', @input
        InboxTestUtils.keyPress 'down', @input
        InboxTestUtils.keyPress 'down', @input
        expect(@participants.state.selectedIndex).toEqual 1

      it 'should be able to select the last one', ->
        InboxTestUtils.keyPress 'down', @input
        InboxTestUtils.keyPress 'down', @input
        InboxTestUtils.keyPress 'down', @input
        expect(@participants.state.selectedIndex).toEqual 4

      it 'should select an item underneath the selectedIndex with "enter"', ->
        InboxTestUtils.keyPress 'up', @input
        InboxTestUtils.keyPress 'enter', @input
        expect(@onAdd).toHaveBeenCalledWith participant4

      it 'should select an item underneath the selectedIndex with "comma"', ->
        InboxTestUtils.keyPress 'up', @input
        InboxTestUtils.keyPress ',', @input
        expect(@onAdd).toHaveBeenCalledWith participant4

      it 'should select an item underneath the selectedIndex with "tab"', ->
        InboxTestUtils.keyPress 'up', @input
        InboxTestUtils.keyPress 'tab', @input
        expect(@onAdd).toHaveBeenCalledWith participant4

      it 'should select an index using the mouse', ->
        ReactTestUtils.Simulate.mouseOver(@completions.getDOMNode().querySelectorAll('li')[3])
        expect(@participants.state.selectedIndex).toEqual 4

      it 'should add a "seen" class to seen participants', ->
        InboxTestUtils.keyPress 'down', @input
        hovered = ReactTestUtils.scryRenderedDOMComponentsWithClass(@participants, "hover")
        expect(hovered.length).toEqual 1
        participant = ReactTestUtils.scryRenderedComponentsWithType(hovered[0], ComposerParticipant)
        expect(participant?[0].props?.participant).toEqual participant2

  it 'should work if two are in the same document', ->
    onAdd = jasmine.createSpy 'add'
    nevercalled = jasmine.createSpy 'nevercalled'
    participants = ReactTestUtils.renderIntoDocument(
      <div>
        <ComposerParticipants
          participants={default_participants}
          participantFunctions={{
          add: onAdd
          remove: nevercalled
          search: nevercalled
          }}
        />
        <ComposerParticipants
          participants={default_participants}
          participantFunctions={{
          add: nevercalled
          remove: nevercalled
          search: nevercalled
          }}
        />
      </div>
    )
    first = ReactTestUtils.scryRenderedComponentsWithType(participants, ComposerParticipants)[0]
    spyOn(ContactStore, 'searchContacts').andReturn(all_participants)
    atom.keymaps.add keymap_path, keymap_file
    input = first.refs.autocomplete.getDOMNode()
    input.focus()
    ReactTestUtils.Simulate.focus(input)
    input.value = 'z'
    ReactTestUtils.Simulate.change(input)
    InboxTestUtils.keyPress 'up', input
    InboxTestUtils.keyPress 'enter', input
    expect(onAdd).toHaveBeenCalledWith participant4
    expect(nevercalled).not.toHaveBeenCalled()
