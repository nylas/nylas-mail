import {Category, Actions} from "nylas-exports"
import SidebarItem from "../lib/sidebar-item"

describe("sidebar-item", function sidebarItemSpec() {
  it("preserves nested labels on rename", () => {
    spyOn(Actions, "queueTask")
    const categories = [new Category({displayName: 'a.b/c', accountId: window.TEST_ACCOUNT_ID})]
    NylasEnv.savedState.sidebarKeysCollapsed = {}
    const item = SidebarItem.forCategories(categories)
    item.onEdited(item, 'd')
    const task = Actions.queueTask.calls[0].args[0]
    expect(task.displayName).toBe("a.b/d")
  })
  it("preserves labels on rename", () => {
    spyOn(Actions, "queueTask")
    const categories = [new Category({displayName: 'a', accountId: window.TEST_ACCOUNT_ID})]
    NylasEnv.savedState.sidebarKeysCollapsed = {}
    const item = SidebarItem.forCategories(categories)
    item.onEdited(item, 'b')
    const task = Actions.queueTask.calls[0].args[0]
    expect(task.displayName).toBe("b")
  })
})
