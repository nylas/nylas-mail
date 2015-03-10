React = require "react"
Reflux = require 'reflux'
Actions = require './flux/actions'
Sheet = require './sheet'

SheetStore = Reflux.createStore
  init: ->
    @_stack = []
    @pushSheet(<Sheet type="Root" depth=0 key="0" />)

    @listenTo Actions.popSheet, @popSheet
    
  # Exposed Data

  pushSheet: (sheet) ->
    @_stack.push(sheet)
    @trigger()
  
  popSheet: ->
    @_stack.pop()
    @trigger()

  topSheet: ->
    @_stack[@_stack.length - 1]

  stack: ->
    @_stack

module.exports = SheetStore
