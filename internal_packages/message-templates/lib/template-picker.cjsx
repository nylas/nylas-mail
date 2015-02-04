_ = require 'underscore-plus'
React = require 'react'
TemplateStore = require './template-store'
{Actions, Message, DatabaseStore} = require 'inbox-exports'
{Popover, Menu} = require 'ui-components'

module.exports =
TemplatePicker = React.createClass

  getInitialState: ->
    searchValue: ""
    templates: TemplateStore.items()

  componentDidMount: ->
    @unsubscribe = TemplateStore.listen @_onStoreChange

  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    button = <button className="btn btn-icon"><i className="fa fa-paste"></i></button>
    headerComponents = [
      <input type="text"
             tabIndex="1"
             className="search native-key-bindings"
             value={@state.searchValue}
             onChange={@_onSearchValueChange}/>
    ]

    footerComponents = [
      <div className="item" key="new" onClick={@_onNewTemplate}>Save as Template...</div>
      <div className="item" key="manage" onClick={@_onManageTemplates}>Open Templates Folder...</div>
    ]

    <Popover ref="popover" className="template-picker" buttonComponent={button}>
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

