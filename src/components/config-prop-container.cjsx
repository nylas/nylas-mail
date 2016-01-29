React = require 'react'
_ = require 'underscore'

class ConfigPropContainer extends React.Component
  @displayName: 'ConfigPropContainer'

  constructor: (@props) ->
    @state = @getStateFromStores()

  componentDidMount: =>
    @subscription = NylasEnv.config.onDidChange null, =>
      @setState(@getStateFromStores())

  componentWillUnmount: =>
    @subscription?.dispose()

  getStateFromStores: =>
    config: @getConfigWithMutators()

  getConfigWithMutators: =>
    _.extend NylasEnv.config.get(), {
      get: (key) =>
        NylasEnv.config.get(key)
      set: (key, value) =>
        NylasEnv.config.set(key, value)
        return
      toggle: (key) =>
        NylasEnv.config.set(key, !NylasEnv.config.get(key))
        return
      contains: (key, val) =>
        vals = NylasEnv.config.get(key)
        return false unless vals and vals instanceof Array
        return val in vals
      toggleContains: (key, val) =>
        vals = NylasEnv.config.get(key)
        vals = [] unless vals and vals instanceof Array
        if val in vals
          NylasEnv.config.set(key, _.without(vals, val))
        else
          NylasEnv.config.set(key, vals.concat([val]))
        return
    }

  render: =>
    React.cloneElement(@props.children, {
      config: @state.config,
      configSchema: NylasEnv.config.getSchema('core')
    })

module.exports = ConfigPropContainer
