# # Filters
#
# A way to apply filters, AKA mail rules, to incoming mail.

Filters = require './filters'
# Requiring 'nylas-exports' is the way to access core N1 components.
{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'

# Your main.coffee (or main.cjsx) file needs to export an object for your
# package to run.
module.exports =
  # When your package is loading, the `activate` method runs. `activate` is the
  # package's time to insert React components into the applicatio and also
  # listen to events.
  activate: ->
    # `WorkspaceStore.defineSheet` creates an N1 "sheet," which is a large area
    # for you to inject React components. Sheets span the whole window.
    WorkspaceStore.defineSheet 'Filters', {root: true, name: 'Filters'},
      list: ['RootSidebar', 'Filters']

    # Above, we named the sheet "Filters," and we're registering a React
    # component to live inside the "Filters" sheet.
    ComponentRegistry.register Filters,
      location: WorkspaceStore.Location.Filters

    # `WorkspaceStore.SidebarItem` is a React component which is meant to be
    # inserted into the navigation bar on the left of the main worksheet.
    @sidebarItem = new WorkspaceStore.SidebarItem
      sheet: WorkspaceStore.Sheet.Filters
      id: 'Filters'
      name: 'Filters'

    # And this is how we actually insert the SidebarItem into the sheet!
    WorkspaceStore.addSidebarItem(@sidebarItem)

  # `deactivate` is called when packages are closing. It's a good time to
  # unregister React components.
  deactivate: ->
    ComponentRegistry.unregister Filters
