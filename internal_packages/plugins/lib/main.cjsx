PluginsView = require "./plugins-view"
PluginsTabsView = require "./plugins-tabs-view"

{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'

module.exports =

  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Plugins', {root: true, name: 'Plugins', supportedModes: ['list']},
      list: ['RootSidebar', 'Plugins']

    @sidebarItem = new WorkspaceStore.SidebarItem
      sheet: WorkspaceStore.Sheet.Plugins
      id: 'Plugins'
      name: 'Plugins'
      section: 'Views'

    WorkspaceStore.addSidebarItem(@sidebarItem)

    ComponentRegistry.register PluginsView,
      location: WorkspaceStore.Location.Plugins

  deactivate: ->
    ComponentRegistry.unregister(PluginsView)
    ComponentRegistry.unregister(PluginsTabsView)
    WorkspaceStore.undefineSheet('Plugins')
