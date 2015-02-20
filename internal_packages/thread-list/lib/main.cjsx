_ = require 'underscore-plus'
React = require "react"
{ComponentRegistry} = require "inbox-exports"
ThreadListTabular = require "./thread-list-tabular"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register
      view: ThreadListTabular
      name: 'ThreadListTabular'
      role: 'ThreadList:Center'
