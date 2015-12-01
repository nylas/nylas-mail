React = require 'react'
_ = require 'underscore'
_str = require 'underscore.string'

###
This component renders input controls for a subtree of the N1 config-schema
and reads/writes current values using the `config` prop, which is expected to
be an instance of the config provided by `ConfigPropContainer`.

The config schema follows the JSON Schema standard: http://json-schema.org/
###
class ConfigSchemaItem extends React.Component
  @displayName: 'ConfigSchemaItem'
  @propTypes:
    config: React.PropTypes.object
    configSchema: React.PropTypes.object
    keyPath: React.PropTypes.string

  render: ->
    return false unless @_appliesToPlatform()
    if @props.configSchema.type is 'object'
      <section>
        <h2>{_str.humanize(@props.keyName)}</h2>
        {_.pairs(@props.configSchema.properties).map ([key, value]) =>
          <ConfigSchemaItem
            key={key}
            keyName={key}
            keyPath={"#{@props.keyPath}.#{key}"}
            configSchema={value}
            config={@props.config}
          />
        }
      </section>

    else if @props.configSchema['enum']?
      <div className="item">
        <label htmlFor={@props.keyPath}>{@props.configSchema.title}:</label>
        <select onChange={@_onChangeValue} value={@props.config.get(@props.keyPath)}>
          {_.zip(@props.configSchema.enum, @props.configSchema.enumLabels).map ([value, label]) =>
            <option key={value} value={value}>{label}</option>
          }
        </select>
      </div>

    else if @props.configSchema.type is 'boolean'
      <div className="item">
        <input id={@props.keyPath} type="checkbox" onChange={@_onChangeChecked} checked={ @props.config.get(@props.keyPath) }/>
        <label htmlFor={@props.keyPath}>{@props.configSchema.title}</label>
      </div>
    else
      <span></span>

  _appliesToPlatform: =>
    return true if not @props.configSchema.platforms?
    return true if process.platform in @props.configSchema.platforms
    return false

  _onChangeChecked: (event) =>
    @props.config.toggle(@props.keyPath)
    event.target.blur()

  _onChangeValue: (event) =>
    @props.config.set(@props.keyPath, event.target.value)
    event.target.blur()

module.exports = ConfigSchemaItem
