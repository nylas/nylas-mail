_ = require 'underscore'
React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
CategoryPicker = require '../lib/category-picker'
{Popover} = require 'nylas-component-kit'

{Utils,
 Label,
 Folder,
 Thread,
 Actions,
 CategoryStore,
 DatabaseStore,
 ChangeLabelsTask,
 ChangeFolderTask,
 SyncbackCategoryTask,
 FocusedMailViewStore,
 TaskQueueStatusStore} = require 'nylas-exports'

describe 'CategoryPicker', ->
  beforeEach ->
    CategoryStore._categoryCache = {}

  afterEach ->
    atom.testOrganizationUnit = null

  setupFor = (organizationUnit) ->
    atom.testOrganizationUnit = organizationUnit
    klass = if organizationUnit is "label" then Label else Folder

    @inboxCategory = new klass(id: 'id-123', name: 'inbox', displayName: "INBOX")
    @archiveCategory = new klass(id: 'id-456', name: 'archive', displayName: "ArCHIVe")
    @userCategory = new klass(id: 'id-789', name: null, displayName: "MyCategory")

    spyOn(CategoryStore, "getStandardCategories").andReturn [ @inboxCategory, @archiveCategory ]
    spyOn(CategoryStore, "getUserCategories").andReturn [ @userCategory ]
    spyOn(CategoryStore, "getStandardCategory").andReturn @inboxCategory

    # By default we're going to set to "inbox". This has implications for
    # what categories get filtered out of the list.
    f = FocusedMailViewStore
    f._setMailView f._defaultMailView()

  setupForCreateNew = (orgUnit = "folder") ->
    setupFor.call(@, orgUnit)

    @testThread = new Thread(id: 't1', subject: "fake")
    @picker = ReactTestUtils.renderIntoDocument(
      <CategoryPicker thread={@testThread} />
    )

    @popover = ReactTestUtils.findRenderedComponentWithType @picker, Popover
    @popover.open()

  describe 'when using labels', ->
    beforeEach ->
      setupFor.call(@, "label")

  describe 'when using folders', ->
    beforeEach ->
      setupFor.call(@, "folder")

      @testThread = new Thread(id: 't1', subject: "fake")
      @picker = ReactTestUtils.renderIntoDocument(
        <CategoryPicker thread={@testThread} />
      )

    it 'lists the desired categories', ->
      data = @picker.state.categoryData
      # NOTE: The inbox category is not included here because it's the
      # currently focused category, which gets filtered out of the list.
      expect(data[0].id).toBe "id-456"
      expect(data[0].name).toBe "archive"
      expect(data[0].category).toBe @archiveCategory
      expect(data[1].divider).toBe true
      expect(data[1].id).toBe "category-divider"
      expect(data[2].id).toBe "id-789"
      expect(data[2].name).toBeUndefined()
      expect(data[2].category).toBe @userCategory

    xdescribe 'when picking for a single Thread', ->
      it 'renders a picker', ->
        expect(ReactTestUtils.isCompositeComponentWithType @picker, CategoryPicker).toBe true

      it "does not include a newItem prompt if there's no search", ->
        outData = @picker._recalculateState().categoryData
        newItem = _.findWhere(outData, newCategoryItem: true)
        l1 = _.findWhere(outData, id: 'id-123')
        expect(newItem).toBeUndefined()
        expect(l1.name).toBe "inbox"

      it "includes a newItem selector with the current search term", ->

    xdescribe 'when picking labels for a single Thread', ->
      beforeEach ->
        atom.testOrganizationUnit = "label"

  describe "'create new' item", ->
    beforeEach ->
      setupForCreateNew.call @

    afterEach -> atom.testOrganizationUnit = null

    it "is not visible when the search box is empty", ->
      count = ReactTestUtils.scryRenderedDOMComponentsWithClass(@picker, 'category-create-new').length
      expect(count).toBe 0

    it "is visible when the search box has text", ->
      inputNode = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithTag(@picker, "input")[0])
      ReactTestUtils.Simulate.change inputNode, target: { value: "calendar" }
      count = ReactTestUtils.scryRenderedDOMComponentsWithClass(@picker, 'category-create-new').length
      expect(count).toBe 1

    it "shows folder icon if we're using exchange", ->
      inputNode = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithTag(@picker, "input")[0])
      ReactTestUtils.Simulate.change inputNode, target: { value: "calendar" }
      count = ReactTestUtils.scryRenderedDOMComponentsWithClass(@picker, 'category-create-new-folder').length
      expect(count).toBe 1

  describe "'create new' item with labels", ->
    beforeEach ->
      setupForCreateNew.call @, "label"

    it "shows label icon if we're using gmail", ->
      inputNode = React.findDOMNode(ReactTestUtils.scryRenderedDOMComponentsWithTag(@picker, "input")[0])
      ReactTestUtils.Simulate.change inputNode, target: { value: "calendar" }
      count = ReactTestUtils.scryRenderedDOMComponentsWithClass(@picker, 'category-create-new-tag').length
      expect(count).toBe 1

  describe "_onSelectCategory()", ->
    describe "using labels", ->
      beforeEach ->
        setupForCreateNew.call @, "label"
        spyOn Actions, "queueTask"

      it "adds a label if it was previously unused", ->
        input = { usage: 0, newCategoryItem: undefined, category: "asdf" }

        @picker._onSelectCategory input

        expect(Actions.queueTask).toHaveBeenCalled()

        labelsToAdd = Actions.queueTask.calls[0].args[0].labelsToAdd
        expect(labelsToAdd.length).toBe 1
        expect(labelsToAdd[0]).toEqual input.category

        threadsToUpdate = Actions.queueTask.calls[0].args[0].threads
        expect(threadsToUpdate).toEqual [ @testThread ]

      it "removes a label if it was previously used", ->
        input = { usage: 1, newCategoryItem: undefined, category: "asdf" }

        @picker._onSelectCategory input

        expect(Actions.queueTask).toHaveBeenCalled()

        labelsToRemove = Actions.queueTask.calls[0].args[0].labelsToRemove
        expect(labelsToRemove.length).toBe 1
        expect(labelsToRemove[0]).toEqual input.category

        threadsToUpdate = Actions.queueTask.calls[0].args[0].threads
        expect(threadsToUpdate).toEqual [ @testThread ]

      it "creates a new label task", ->
        input = { newCategoryItem: true }

        @picker.setState searchValue: "teSTing!"

        @picker._onSelectCategory input

        expect(Actions.queueTask).toHaveBeenCalled()

        syncbackTask = Actions.queueTask.calls[0].args[0]
        newCategory  = syncbackTask.category
        expect(syncbackTask.organizationUnit).toBe "label"
        expect(newCategory.displayName).toBe "teSTing!"
        expect(newCategory.accountId).toBe TEST_ACCOUNT_ID

      it "queues a change label task after performRemote for creating it", ->
        input = { newCategoryItem: true }
        label = new Label(clientId: "local-123")

        spyOn(TaskQueueStatusStore, "waitForPerformRemote").andCallFake (task) ->
          expect(task instanceof SyncbackCategoryTask).toBe true
          Promise.resolve()
        spyOn(DatabaseStore, "findBy").andCallFake (klass, {clientId}) ->
          expect(klass).toBe Label
          expect(typeof clientId).toBe "string"
          Promise.resolve label

        runs ->
          @picker.setState searchValue: "teSTing!"
          @picker._onSelectCategory input

        waitsFor -> Actions.queueTask.calls.length > 1

        runs ->
          changeLabelsTask = Actions.queueTask.calls[1].args[0]
          expect(changeLabelsTask instanceof ChangeLabelsTask).toBe true
          expect(changeLabelsTask.labelsToAdd).toEqual [ label ]
          expect(changeLabelsTask.threads).toEqual [ @testThread ]

      it "doesn't queue any duplicate syncback tasks", ->
        input = { newCategoryItem: true }
        label = new Label(clientId: "local-123")

        spyOn(TaskQueueStatusStore, "waitForPerformRemote").andCallFake (task) ->
          expect(task instanceof SyncbackCategoryTask).toBe true
          Promise.resolve()
        spyOn(DatabaseStore, "findBy").andCallFake (klass, {clientId}) ->
          expect(klass).toBe Label
          expect(typeof clientId).toBe "string"
          Promise.resolve label

        runs ->
          @picker.setState searchValue: "teSTing!"
          @picker._onSelectCategory input

        waitsFor -> Actions.queueTask.calls.length > 1

        runs ->
          allInputs = Actions.queueTask.calls.map (c) -> c.args[0]
          syncbackTasks = allInputs.filter (i) -> i instanceof SyncbackCategoryTask
          expect(syncbackTasks.length).toBe 1

    describe "using folders", ->
      beforeEach ->
        setupForCreateNew.call @, "folder"
        spyOn Actions, "queueTask"
        spyOn Actions, "moveThread"
        spyOn Actions, "moveThreads"

      it "moves a thread if the component has one", ->
        input = { category: "blah" }
        @picker._onSelectCategory input
        expect(Actions.moveThread).toHaveBeenCalled()

        args = Actions.moveThread.calls[0].args
        expect(args[0]).toEqual @testThread
        expect(args[1].folder).toEqual input.category
        expect(args[1].threads).toEqual [ @testThread ]

      it "moves threads if the component has no thread but has items", ->
        @picker = ReactTestUtils.renderIntoDocument(
          <CategoryPicker items={[@testThread]} />
        )
        @popover = ReactTestUtils.findRenderedComponentWithType @picker, Popover
        @popover.open()

        input = { category: "blah" }
        @picker._onSelectCategory input
        expect(Actions.moveThreads).toHaveBeenCalled()

      it "creates a new folder task", ->
        input = { newCategoryItem: true }
        folder = new Folder(clientId: "local-456", serverId: "yes.")

        spyOn(TaskQueueStatusStore, "waitForPerformRemote").andCallFake (task) ->
          expect(task instanceof SyncbackCategoryTask).toBe true
          Promise.resolve()
        spyOn(DatabaseStore, "findBy").andCallFake (klass, {clientId}) ->
          expect(klass).toBe Folder
          expect(typeof clientId).toBe "string"
          Promise.resolve folder

        runs ->
          @picker.setState searchValue: "teSTing!"
          @picker._onSelectCategory input

        waitsFor -> Actions.moveThread.calls.length > 0

        runs ->
          changeFoldersTask = Actions.moveThread.calls[0].args[1]
          expect(changeFoldersTask instanceof ChangeFolderTask).toBe true
          expect(changeFoldersTask.folder).toEqual folder
          expect(changeFoldersTask.threads).toEqual [ @testThread ]

    it "closes the popover", ->
      setupForCreateNew.call @, "folder"
      spyOn @popover, "close"
      spyOn Actions, "moveThread"
      @picker._onSelectCategory { usage: 0, category: "asdf" }
      expect(@popover.close).toHaveBeenCalled()
