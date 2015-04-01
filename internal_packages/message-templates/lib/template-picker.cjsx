_ = require 'underscore-plus'
React = require 'react'
TemplateStore = require './template-store'
{Actions, Message, DatabaseStore} = require 'inbox-exports'
{Popover, Menu, RetinaImg} = require 'ui-components'

module.exports =
TemplatePicker = React.createClass
  displayName: 'TemplatePicker'

  getInitialState: ->
    searchValue: ""
    templates: TemplateStore.items()

  componentDidMount: ->
    @unsubscribe = TemplateStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    button = <button className="btn btn-toolbar">
      <RetinaImg name="toolbar-templates.png"/>
      <RetinaImg name="toolbar-chevron.png"/>
    </button>
    headerComponents = [
      <input type="text"
             tabIndex="1"
             className="search"
             value={@state.searchValue}
             onChange={@_onSearchValueChange}/>
    ]

    footerComponents = [
      <div className="item" key="new" onMouseDown={@_onNewTemplate}>Save as Template...</div>
      <div className="item" key="manage" onMouseDown={@_onManageTemplates}>Open Templates Folder...</div>
    ]

    <Popover ref="popover" className="template-picker pull-right" buttonComponent={button}>
      <Menu ref="menu"
            headerComponents={headerComponents}
            footerComponents={footerComponents}
            items={@state.templates}
            itemKey={ (item) -> item.id }
            itemContent={ (item) -> item.name }
            onSelect={@_onChooseTemplate}
            />
    </Popover>


  _filteredTemplates: (search) ->
    search ?= @state.searchValue
    items = TemplateStore.items()

    return items unless search.length

    _.filter items, (t) ->
      t.name.toLowerCase().indexOf(search.toLowerCase()) == 0

  _onStoreChange: ->
    @setState
      templates: @_filteredTemplates()

  _onSearchValueChange: ->
    newSearch = event.target.value
    @setState
      searchValue: newSearch
      templates: @_filteredTemplates(newSearch)

  _onChooseTemplate: (template) ->
    Actions.insertTemplateId({templateId:template.id, draftLocalId: @props.draftLocalId})
    @refs.popover.close()

  _onManageTemplates: ->
    Actions.showTemplates()

  _onNewTemplate: ->
    Actions.createTemplate({draftLocalId: @props.draftLocalId})

