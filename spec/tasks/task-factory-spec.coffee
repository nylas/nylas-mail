# Account = require '../../src/flux/models/account'
# CategoryStore = require '../../src/flux/stores/category-store'
# RemoveThreadHelper = require '../../src/services/remove-thread-helper'
#
# ChangeFolderTask = require '../../src/flux/tasks/change-folder-task'
# ChangeLabelsTask = require '../../src/flux/tasks/change-labels-task'
#
# describe "RemoveThreadHelper", ->
#   describe "removeType", ->
#     it "returns null if there's no current account", ->
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn null
#       expect(RemoveThreadHelper.removeType()).toBe null
#
#     it "returns the type if it's saved", ->
#       spyOn(NylasEnv.config, "get").andReturn "trash"
#       expect(RemoveThreadHelper.removeType()).toBe "trash"
#
#     it "returns the archive category if it exists", ->
#       spyOn(CategoryStore, "getStandardCategory").andReturn {name: "archive"}
#       expect(RemoveThreadHelper.removeType()).toBe "archive"
#
#     it "defaults to archive for Gmail", ->
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn provider: "gmail"
#       expect(RemoveThreadHelper.removeType()).toBe "archive"
#
#     it "defaults to trash for everything else", ->
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn provider: "eas"
#       expect(RemoveThreadHelper.removeType()).toBe "trash"
#
#   describe "getRemovalTask", ->
#     beforeEach ->
#       spyOn(CategoryStore, "byId").andReturn({id: "inbox-id", name: "inbox"})
#       @mailboxPerspectiveStub = categoryId: -> "inbox-id"
#       @categories = []
#
#       spyOn(CategoryStore, "getStandardCategory").andCallFake (cat) =>
#         if cat in @categories
#           return {id: "cat-id", name: cat}
#         else return null
#
#     afterEach ->
#       NylasEnv.testOrganizationUnit = null
#
#     it "returns null if there's no current account", ->
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn null
#       expect(RemoveThreadHelper.getRemovalTask()).toBe null
#
#     it "creates the task when using labels and trashing", ->
#       NylasEnv.testOrganizationUnit = "label"
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn new Account
#         provider: "eas"
#         organizationUnit: "label"
#       @categories = ["all", "trash"]
#       t = RemoveThreadHelper.getRemovalTask([], @mailboxPerspectiveStub)
#       expect(t instanceof ChangeLabelsTask).toBe true
#       expect(t.labelsToRemove[0].name).toBe "inbox"
#       expect(t.labelsToAdd[0].name).toBe "trash"
#
#     it "creates the task when using labels and archiving", ->
#       @categories = ["all", "archive", "trash"]
#       NylasEnv.testOrganizationUnit = "label"
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn new Account
#         provider: "gmail"
#         organizationUnit: "label"
#       t = RemoveThreadHelper.getRemovalTask([], @mailboxPerspectiveStub)
#       expect(t instanceof ChangeLabelsTask).toBe true
#       expect(t.labelsToRemove[0].name).toBe "inbox"
#       expect(t.labelsToAdd[0].name).toBe "all"
#
#     it "creates the task when using folders and trashing", ->
#       @categories = ["all", "trash"]
#       NylasEnv.testOrganizationUnit = "folder"
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn new Account
#         provider: "eas"
#         organizationUnit: "folder"
#       t = RemoveThreadHelper.getRemovalTask([], @mailboxPerspectiveStub)
#       expect(t instanceof ChangeFolderTask).toBe true
#       expect(t.folder.name).toBe "trash"
#
#     it "creates the task when using folders and archiving", ->
#       @categories = ["all", "archive", "trash"]
#       NylasEnv.testOrganizationUnit = "folder"
#       spyOn(RemoveThreadHelper, "_currentAccount").andReturn new Account
#         provider: "gmail"
#         organizationUnit: "folder"
#       t = RemoveThreadHelper.getRemovalTask([], @mailboxPerspectiveStub)
#       expect(t instanceof ChangeFolderTask).toBe true
#       expect(t.folder.name).toBe "archive"
