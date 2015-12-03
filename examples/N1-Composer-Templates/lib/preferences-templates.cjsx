_ = require 'underscore'
{Contenteditable, RetinaImg, Flexbox} = require 'nylas-component-kit'
{AccountStore, Utils, React} = require 'nylas-exports'
TemplateStore = require './template-store';

class PreferencesTemplates extends React.Component
  @displayName: 'PreferencesTemplates'

  constructor: (@props) ->
    TemplateStore.init();
    @_templateSaveQueue = {}

    @state =
      editAsHTML: false
      editState: null
      templates: []
      selectedTemplate: null
      selectedTemplateName: null
      contents: null

  componentDidMount: ->
    @usub = TemplateStore.listen @_onChange

  componentWillUnmount: ->
    @usub()
    if @state.selectedTemplate?
      @_saveTemplateNow(@state.selectedTemplate.name, @state.contents)



  #SAVING AND LOADING TEMPLATES
  _loadTemplateContents: (template) =>
    if template
      TemplateStore.getTemplateContents(template.id, (contents) =>
        @setState({contents: contents})
      )

  _saveTemplateNow: (name, contents, callback) =>
    TemplateStore.saveTemplate(name, contents, false, callback)

  _saveTemplateSoon: (name, contents) =>
    @_templateSaveQueue[name] = contents
    @_saveTemplatesFromCache()

  __saveTemplatesFromCache: =>
    for name, contents of @_templateSaveQueue
      @_saveTemplateNow(name, contents)

    @_templateSaveQueue = {}

  _saveTemplatesFromCache: _.debounce(PreferencesTemplates::__saveTemplatesFromCache, 500)



  # OVERALL STATE HANDLING
  _onChange: =>
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    templates = TemplateStore.items()
    selectedTemplate = @state.selectedTemplate
    if selectedTemplate? and selectedTemplate.id not in _.pluck(templates, "id")
      selectedTemplate = null
    else if not selectedTemplate?
      selectedTemplate = if templates.length > 0 then templates[0] else null
    @_loadTemplateContents(selectedTemplate)
    if selectedTemplate?
      selectedTemplateName = @state.selectedTemplateName || selectedTemplate.name
    return {templates, selectedTemplate, selectedTemplateName}



  # TEMPLATE CONTENT EDITING
  _onEditTemplate: (event) =>
    html = event.target.value
    @setState contents: html
    if @state.selectedTemplate?
      @_saveTemplateSoon(@state.selectedTemplate.name, html)

  _onSelectTemplate: (event) =>
    if @state.selectedTemplate?
      @_saveTemplateNow(@state.selectedTemplate.name, @state.contents)
    selectedTemplate = null
    for template in @state.templates
      if template.id == event.target.value
        selectedTemplate = template
    @setState
      selectedTemplate: selectedTemplate
      selectedTemplateName: selectedTemplate?.name
      contents: null
    @_loadTemplateContents(selectedTemplate)

  _renderTemplatePicker: ->
    options = @state.templates.map (template) ->
      <option value={template.id} key={template.id}>{template.name}</option>

    <select value={@state.selectedTemplate?.id} onChange={@_onSelectTemplate}>
      {options}
    </select>

  _renderEditableTemplate: ->
    <Contenteditable
       ref="templateInput"
       value={@state.contents}
       onChange={@_onEditTemplate}
       spellcheck={false} />

  _renderHTMLTemplate: ->
    <textarea ref="templateHTMLInput"
              value={@state.contents}
              onChange={@_onEditTemplate}/>

  _renderModeToggle: ->
    if @state.editAsHTML
      return <a onClick={=> @setState(editAsHTML: false); return}>Edit live preview</a>
    else
      return <a onClick={=> @setState(editAsHTML: true); return}>Edit raw HTML</a>



  # TEMPLATE NAME EDITING
  _renderEditName: ->
    <div className="section-title">
      Template Name: <input type="text" className="template-name-input" value={@state.selectedTemplateName} onChange={@_onEditName}/>
      <button className="btn template-name-btn" onClick={@_saveName}>Save Name</button>
      <button className="btn template-name-btn" onClick={@_cancelEditName}>Cancel</button>
    </div>

  _renderName: ->
    rawText = if @state.editAsHTML then "Raw HTML " else ""
    <div className="section-title">
      {rawText}Template: {@_renderTemplatePicker()}
      <button className="btn template-name-btn" title="New template" onClick={@_startNewTemplate}>New</button>
      <button className="btn template-name-btn" onClick={ => @setState(editState: "name") }>Rename</button>
    </div>

  _onEditName: =>
    @setState({selectedTemplateName: event.target.value})

  _cancelEditName: =>
    @setState
      selectedTemplateName: @state.selectedTemplate?.name
      editState: null

  _saveName: =>
    if @state.selectedTemplate?.name != @state.selectedTemplateName
      TemplateStore.renameTemplate(@state.selectedTemplate.name, @state.selectedTemplateName, (renamedTemplate) =>
        @setState
          selectedTemplate: renamedTemplate
          editState: null
      )
    else
      @setState
        editState: null


  # DELETE AND NEW
  _deleteTemplate: =>
    if @state.selectedTemplate?
      TemplateStore.deleteTemplate(@state.selectedTemplate.name)

  _startNewTemplate: =>
    @setState
      editState: "new"
      selectedTemplate: null
      selectedTemplateName: ""
      contents: ""

  _saveNewTemplate: =>
    TemplateStore.saveTemplate(@state.selectedTemplateName, @state.contents, true, (template) =>
      @setState
        selectedTemplate: template
        editState: null
    )

  _cancelNewTemplate: =>
    template = if @state.templates.length>0 then @state.templates[0] else null
    @setState
      selectedTemplate: template
      selectedTemplateName: template?.name
      editState: null
    @_loadTemplateContents(template)

  _renderCreateNew: ->
    <div className="section-title">
      Template Name: <input type="text" className="template-name-input" value={@state.selectedTemplateName} onChange={@_onEditName}/>
      <button className="btn btn-emphasis template-name-btn" onClick={@_saveNewTemplate}>Save</button>
      <button className="btn template-name-btn" onClick={@_cancelNewTemplate}>Cancel</button>
    </div>


  # MAIN RENDER
  render: =>
    deleteBtn =
      <button className="btn template-name-btn" title="Delete template" onClick={@_deleteTemplate}>
        <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>

    <div>
    <section className="container-templates">
      <h2>Quick Replies</h2>
      {
        switch @state.editState
          when "name" then @_renderEditName()
          when "new" then @_renderCreateNew()
          else @_renderName()
      }
      <div className="template-wrap">
        {if @state.editAsHTML then @_renderHTMLTemplate() else @_renderEditableTemplate()}
      </div>
      <span className="editor-note">
        { if _.size(@_templateSaveQueue) > 0 then "Saving changes..." else "Changes saved." }
      </span>
      <span style={float:"right"}>{if @state.editState == null then deleteBtn else ""}</span>
      <div className="toggle-mode" style={marginTop: "1em"}>
        {@_renderModeToggle()}
      </div>
    </section>

    <section className="templates-instructions">
    <p>
      The Quick Replies plugin lets you write preset templates to use as email responses. Replies can contain variables, which
      you can quickly jump between and fill out when using the template.
    </p>
    <p>
      Variables are defined as HTML &lt;code&gt; tags with class "var". You can include these by editing the raw HTML of the template and adding <code>&lt;code class="var"&gt;[content]&lt;/code&gt;</code>. Add
      the "empty" class to make a region dark yellow and indicate that it should be filled in. When you send your message, &lt;code&gt;
      tags are always stripped so the recipient never sees any highlighting.
    </p>
    <p>
      Templates live in the <strong>~/.nylas/templates</strong> directory on your computer. Each template
      is an HTML file - the name of the file is the name of the template, and its contents are the default message body.
    </p>

    </section>
    </div>

module.exports = PreferencesTemplates
