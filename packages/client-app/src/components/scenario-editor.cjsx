React = require 'react'
_ = require 'underscore'
{Comparator, Template} = require './scenario-editor-models'
ScenarioEditorRow = require './scenario-editor-row'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{Actions, Utils} = require 'nylas-exports'

###
The ScenarioEditor takes an array of ScenarioTemplate objects which define the
scenario value space. Each ScenarioTemplate defines a `key` and it's valid
`comparators` and `values`. The ScenarioEditor gives the user the option to
create and combine instances of different templates to create a scenario.

For example:

  Scenario Space:
   - ScenarioFactory("user-name", "The name of the user")
      + valueType: String
      + comparators: "contains", "starts with", etc.
    - SecnarioFactor("profession", "The profession of the user")
      + valueType: Enum
      + comparators: 'is'

  Scenario Value:
    [{
      'key': 'user-name'
      'comparator': 'contains'
      'value': 'Ben'
    },{
      'key': 'profession'
      'comparator': 'is'
      'value': 'Engineer'
    }]
###

class ScenarioEditor extends React.Component
  @displayName: 'ScenarioEditor'

  @propTypes:
    instances: React.PropTypes.array
    className: React.PropTypes.string
    onChange: React.PropTypes.func
    templates: React.PropTypes.array

  @Template: Template
  @Comparator: Comparator

  constructor: (@props) ->
    @state =
      collapsed: true

  render: =>
    <div className={@props.className}>
    { (@props.instances || []).map (instance, idx) =>
      <ScenarioEditorRow
        key={idx}
        instance={instance}
        removable={@props.instances.length > 1}
        templates={@props.templates}
        onRemove={ => @_onRemoveRule(idx) }
        onInsert={ => @_onInsertRule(idx) }
        onChange={ (instance) => @_onChangeRowValue(instance, idx) } />
    }
    </div>

  _performChange: (block) =>
    instances = JSON.parse(JSON.stringify(@props.instances))
    block(instances)
    @props.onChange(instances)

  _onRemoveRule: (idx) =>
    @_performChange (instances) =>
      return if instances.length is 1
      instances.splice(idx, 1)

  _onInsertRule: (idx) =>
    @_performChange (instances) =>
      instances.push @props.templates[0].createDefaultInstance()

  _onChangeRowValue: (newInstance, idx) =>
    @_performChange (instances) =>
      instances[idx] = newInstance

module.exports = ScenarioEditor
