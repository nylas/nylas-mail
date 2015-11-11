Menu = require 'menu'

module.exports =
class ContextMenu
  constructor: (template, @nylasWindow) ->
    template = @createClickHandlers(template)
    menu = Menu.buildFromTemplate(template)
    menu.popup(@nylasWindow.browserWindow)

  # It's necessary to build the event handlers in this process, otherwise
  # closures are dragged across processes and failed to be garbage collected
  # appropriately.
  createClickHandlers: (template) ->
    for item in template
      if item.command
        item.commandDetail ?= {}
        item.commandDetail.contextCommand = true
        item.commandDetail.nylasWindow = @nylasWindow
        do (item) =>
          item.click = =>
            global.application.sendCommandToWindow(item.command, @nylasWindow, item.commandDetail)
      else if item.submenu
        @createClickHandlers(item.submenu)
      item
