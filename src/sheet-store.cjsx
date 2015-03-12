React = require "react"
Reflux = require 'reflux'
Actions = require './flux/actions'

SheetStore = Reflux.createStore
  init: ->
    @_stack = ["Root"]
    @listenTo Actions.popSheet, @popSheet
    
  # Exposed Data

  pushSheet: (type) ->
    @_stack.push(type)
    @trigger()
  
  popSheet: ->
    @_stack.pop()
    @trigger()

  topSheetType: ->
    @_stack[@_stack.length - 1]

  stack: ->
    @_stack

module.exports = SheetStore
