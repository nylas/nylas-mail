React = require 'react'
_ = require 'underscore'

class ConfigPropContainer extends React.Component
  @displayName: 'ConfigPropContainer'

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @subscription = atom.config.observe null, (val) =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    @subscription?.dispose()

  getStateFromStores: =>
    config: @getConfigWithMutators()

  getConfigWithMutators: =>
    _.extend atom.config.get(), {
      get: (key) =>
        atom.config.get(key)
      set: (key, value) =>
        atom.config.set(key, value)
        return
      toggle: (key) =>
        atom.config.set(key, !atom.config.get(key))
        return
      contains: (key, val) =>
        vals = atom.config.get(key)
        return false unless vals and vals instanceof Array
        return val in vals
      toggleContains: (key, val) =>
        vals = atom.config.get(key)
        vals = [] unless vals and vals instanceof Array
        if val in vals
          atom.config.set(key, _.without(vals, val))
        else
          atom.config.set(key, vals.concat([val]))
        return
    }

  render: =>
    React.cloneElement(@props.children, {config: @state.config})

module.exports = ConfigPropContainer
