React = require 'react'
_ = require 'underscore'
Rx = require 'rx-lite'
{RetinaImg, Flexbox} = require 'nylas-component-kit'
{CategoryStore, Actions, Utils} = require 'nylas-exports'

{Comparator, Template} = require './scenario-editor-models'

SOURCE_SELECT_NULL = 'NULL'

class SourceSelect extends React.Component
  @displayName: 'SourceSelect'
  @propTypes:
    value: React.PropTypes.string
    onChange: React.PropTypes.func.isRequired
    options: React.PropTypes.oneOfType([
      React.PropTypes.object
      React.PropTypes.array
    ]).isRequired

  constructor: (@props) ->
    @state =
      options: []

  componentDidMount: =>
    @_setupValuesSubscription()

  componentWillReceiveProps: (nextProps) =>
    @_setupValuesSubscription(nextProps)

  componentWillUnmount: =>
    @_subscription?.dispose()
    @_subscription = null

  _setupValuesSubscription: (props = @props) =>
    @_subscription?.dispose()
    @_subscription = null
    if props.options instanceof Rx.Observable
      @_subscription = props.options.subscribe (options) =>
        @setState({options})
    else
      @setState(options: props.options)

  render: =>
    options = @state.options

    # The React <select> component won't select the correct option if the value
    # is null or undefined - it just leaves the selection whatever it was in the
    # previous render. To work around this, we coerce null/undefined to SOURCE_SELECT_NULL.

    <select value={@props.value || SOURCE_SELECT_NULL} onChange={@_onChange}>
      <option key={SOURCE_SELECT_NULL} value={SOURCE_SELECT_NULL}></option>
      { @state.options.map ({value, name}) =>
        <option key={value} value={value}>{name}</option>
      }
    </select>

  _onChange: (event) =>
    value = event.target.value
    value = null if value is SOURCE_SELECT_NULL
    @props.onChange(target: {value})

class ScenarioEditorRow extends React.Component
  @displayName: 'ScenarioEditorRow'
  @propTypes:
    instance: React.PropTypes.object.isRequired
    removable: React.PropTypes.bool
    templates: React.PropTypes.array.isRequired
    onChange: React.PropTypes.func
    onInsert: React.PropTypes.func
    onRemove: React.PropTypes.func

  constructor: (@props) ->

  render: =>
    template = _.findWhere(@props.templates, {key: @props.instance.templateKey})
    unless template
      return <span> Could not find template for instance key: {@props.instance.templateKey}</span>

    <Flexbox direction="row" className="well-row">
      <span>
        {@_renderTemplateSelect(template)}
        {@_renderComparator(template)}
        <span>{template.valueLabel}</span>
        {@_renderValue(template)}
      </span>
      <div style={flex: 1}></div>
      {@_renderActions()}
    </Flexbox>

  _renderTemplateSelect: (template) =>
    options = @props.templates.map ({key, name}) =>
      <option value={key} key={key}>{name}</option>

    <select
      value={@props.instance.templateKey}
      onChange={@_onChangeTemplate}>
      {options}
    </select>

  _renderComparator: (template) =>
    options = _.map template.comparators, ({name}, key) =>
      <option key={key} value={key}>{name}</option>

    return false unless options.length > 0

    <select
      value={@props.instance.comparatorKey}
      onChange={@_onChangeComparator}>
      {options}
    </select>

  _renderValue: (template) =>
    if template.type is Template.Type.Enum
      <SourceSelect
        value={@props.instance.value}
        onChange={@_onChangeValue}
        options={template.values} />

    else if template.type is Template.Type.String
      <input
        type="text"
        value={@props.instance.value}
        onChange={@_onChangeValue} />

    else
      false

  _renderActions: =>
    <div className="actions">
      { if @props.removable then <div className="btn" onClick={@props.onRemove}>&minus;</div> }
      <div className="btn" onClick={@props.onInsert}>+</div>
    </div>

  _onChangeValue: (event) =>
    instance = _.clone(@props.instance)
    instance.value = event.target.value
    @props.onChange(instance)

  _onChangeComparator: (event) =>
    instance = _.clone(@props.instance)
    instance.comparatorKey = event.target.value
    @props.onChange(instance)

  _onChangeTemplate: (event) =>
    instance = _.clone(@props.instance)

    existingTemplate = _.findWhere(@props.templates, key: instance.key)
    newTemplate = _.findWhere(@props.templates, key: event.target.value)

    instance = newTemplate.coerceInstance(instance)

    @props.onChange(instance)

module.exports = ScenarioEditorRow
