React = require "react"
ContainerView = require "./container-view"
remote = require "remote"

module.exports =
  item: null

  activate: (@state) ->
    # This package does nothing in other windows
    return unless atom.state.mode is 'onboarding'

    @item = document.createElement("div")
    @item.setAttribute("id", "onboarding-container")
    @item.setAttribute("class", "onboarding-container")
    React.render(<ContainerView /> , @item)
    document.body.appendChild(@item)
