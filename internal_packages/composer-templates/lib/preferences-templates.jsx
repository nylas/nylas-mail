import _ from 'underscore';
import {Contenteditable, RetinaImg} from 'nylas-component-kit';
import {React} from 'nylas-exports';

import TemplateStore from './template-store';
import TemplateEditor from './template-editor';


class PreferencesTemplates extends React.Component {
  static displayName = 'PreferencesTemplates';

  constructor() {
    super();
    this._templateSaveQueue = {};

    const {templates, selectedTemplate, selectedTemplateName} = this._getStateFromStores();
    this.state = {
      editAsHTML: false,
      editState: templates.length === 0 ? "new" : null,
      templates: templates,
      selectedTemplate: selectedTemplate,
      selectedTemplateName: selectedTemplateName,
      contents: null,
    };
  }

  componentDidMount() {
    this.unsub = TemplateStore.listen(this._onChange);
  }

  componentWillUnmount() {
    this.unsub();
    if (this.state.selectedTemplate) {
      this._saveTemplateNow(this.state.selectedTemplate.name, this.state.contents);
    }
  }

  // SAVING AND LOADING TEMPLATES
  _loadTemplateContents = (template) => {
    if (template) {
      TemplateStore.getTemplateContents(template.id, (contents) => {
        this.setState({contents: contents});
      });
    }
  }

  _saveTemplateNow(name, contents, callback) {
    TemplateStore.saveTemplate(name, contents, callback);
  }

  _saveTemplateSoon(name, contents) {
    this._templateSaveQueue[name] = contents;
    this._saveTemplatesFromCache();
  }

  __saveTemplatesFromCache() {
    for (const name of Object.keys(this._templateSaveQueue)) {
      this._saveTemplateNow(name, this._templateSaveQueue[name]);
    }
    this._templateSaveQueue = {};
  }

  _saveTemplatesFromCache = _.debounce(PreferencesTemplates.prototype.__saveTemplatesFromCache, 500);

  // OVERALL STATE HANDLING
  _onChange = () => {
    this.setState(this._getStateFromStores());
  }

  _getStateFromStores() {
    const templates = TemplateStore.items();
    let selectedTemplate = this.state ? this.state.selectedTemplate : null;
    if (selectedTemplate && !_.pluck(templates, "id").includes(selectedTemplate.id)) {
      selectedTemplate = null;
    } else if (!selectedTemplate) {
      selectedTemplate = templates.length > 0 ? templates[0] : null;
    }
    this._loadTemplateContents(selectedTemplate);
    let selectedTemplateName = null;
    if (selectedTemplate) {
      selectedTemplateName = this.state ? this.state.selectedTemplateName : selectedTemplate.name;
    }
    return {templates, selectedTemplate, selectedTemplateName};
  }

  // TEMPLATE CONTENT EDITING
  _onEditTemplate = (event) => {
    const html = event.target.value;
    this.setState({contents: html});
    if (this.state.selectedTemplate) {
      this._saveTemplateSoon(this.state.selectedTemplate.name, html);
    }
  }

  _onSelectTemplate = (event) => {
    if (this.state.selectedTemplate) {
      this._saveTemplateNow(this.state.selectedTemplate.name, this.state.contents);
    }

    const selectedId = event.target.value;
    const selectedTemplate = this.state.templates.find((template) =>
      template.id === selectedId
    );

    this.setState({
      selectedTemplate: selectedTemplate,
      selectedTemplateName: selectedTemplate ? selectedTemplate.name : null,
      contents: null,
    });
    this._loadTemplateContents(selectedTemplate);
  }

  _renderTemplatePicker() {
    const options = this.state.templates.map((template) => {
      return <option value={template.id} key={template.id}>{template.name}</option>
    });

    return (
      <select value={this.state.selectedTemplate ? this.state.selectedTemplate.id : null} onChange={this._onSelectTemplate}>
        {options}
      </select>
    );
  }

  _renderEditableTemplate() {
    return (
      <Contenteditable
        ref="templateInput"
        value={this.state.contents || ""}
        onChange={this._onEditTemplate}
        extensions={[TemplateEditor]}
        spellcheck={false}
      />
    );
  }

  _renderHTMLTemplate() {
    return (
      <textarea
        ref="templateHTMLInput"
        value={this.state.contents || ""}
        onChange={this._onEditTemplate}
      />
    );
  }

  _renderModeToggle() {
    if (this.state.editAsHTML) {
      return (<a onClick={() => { this.setState({editAsHTML: false}); }}>Edit live preview</a>);
    }
    return (<a onClick={() => { this.setState({editAsHTML: true}); }}>Edit raw HTML</a>);
  }

  _onEnter(action) {
    return (event) => {
      if (event.key === "Enter") {
        action()
      }
    }
  }

  // TEMPLATE NAME EDITING
  _renderEditName() {
    return (
      <div className="section-title">
        Template Name: <input type="text" className="template-name-input" value={this.state.selectedTemplateName} onChange={this._onEditName} onKeyDown={this._onEnter(this._saveName)} />
        <button className="btn template-name-btn" onClick={this._saveName}>Save Name</button>
        <button className="btn template-name-btn" onClick={this._cancelEditName}>Cancel</button>
      </div>
    );
  }

  _renderName() {
    const rawText = this.state.editAsHTML ? "Raw HTML " : "";
    return (
      <div className="section-title">
        {rawText}Template: {this._renderTemplatePicker()}
        <button className="btn template-name-btn" title="New template" onClick={this._startNewTemplate}>New</button>
        <button className="btn template-name-btn" onClick={() => { this.setState({editState: "name"}); }}>Rename</button>
      </div>
    );
  }

  _onEditName = (event) => {
    this.setState({selectedTemplateName: event.target.value});
  }

  _cancelEditName = () => {
    this.setState({
      selectedTemplateName: this.state.selectedTemplate ? this.state.selectedTemplate.name : null,
      editState: null,
    });
  }

  _saveName = () => {
    if (this.state.selectedTemplate && this.state.selectedTemplate.name !== this.state.selectedTemplateName) {
      TemplateStore.renameTemplate(this.state.selectedTemplate.name, this.state.selectedTemplateName, (renamedTemplate) => {
        this.setState({
          selectedTemplate: renamedTemplate,
          editState: null,
        });
      });
    } else {
      this.setState({
        editState: null,
      });
    }
  }

  // DELETE AND NEW
  _deleteTemplate = () => {
    const numTemplates = this.state.templates.length;
    if (this.state.selectedTemplate) {
      TemplateStore.deleteTemplate(this.state.selectedTemplate.name);
    }
    if (numTemplates === 1) {
      this.setState({
        editState: "new",
        selectedTemplate: null,
        selectedTemplateName: "",
        contents: "",
      });
    }
  }

  _startNewTemplate = () => {
    this.setState({
      editState: "new",
      selectedTemplate: null,
      selectedTemplateName: "",
      contents: "",
    });
  }

  _saveNewTemplate = () => {
    this.setState({contents: ""})
    TemplateStore.saveNewTemplate(this.state.selectedTemplateName, "", (template) => {
      this.setState({
        selectedTemplate: template,
        editState: null,
      });
    });
  }

  _cancelNewTemplate = () => {
    const template = this.state.templates.length > 0 ? this.state.templates[0] : null;
    this.setState({
      selectedTemplate: template,
      selectedTemplateName: template ? template.name : null,
      editState: null,
    });
    this._loadTemplateContents(template);
  }

  _renderCreateNew() {
    const cancel = (<button className="btn template-name-btn" onClick={this._cancelNewTemplate}>Cancel</button>);
    return (
      <div className="section-title">
        Template Name: <input type="text" className="template-name-input" value={this.state.selectedTemplateName} onChange={this._onEditName} onKeyDown={this._onEnter(this._saveNewTemplate)} />
        <button className="btn btn-emphasis template-name-btn" onClick={this._saveNewTemplate}>Save</button>
        {this.state.templates.length ? cancel : null}
      </div>
    );
  }

  // MAIN RENDER
  render() {
    const deleteBtn = (
      <button className="btn" title="Delete template" onClick={this._deleteTemplate}>
        <RetinaImg name="icon-composer-trash.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    );

    const editor = (
      <div>
        <div className="template-wrap">
          {this.state.editAsHTML ? this._renderHTMLTemplate() : this._renderEditableTemplate()}
        </div>
        <div style={{marginTop: "5px"}}>
          <span className="editor-note">
            {_.size(this._templateSaveQueue) === 0 ? "Changes saved." : ""}
            &nbsp;
          </span>
          <span style={{"float": "right"}}>{this.state.editState === null ? deleteBtn : ""}</span>
        </div>
        <div className="toggle-mode" style={{marginTop: "1em"}}>
          {this._renderModeToggle()}
        </div>
      </div>
    );

    let editContainer = this._renderName();
    if (this.state.editState === "name") {
      editContainer = this._renderEditName();
    } else if (this.state.editState === "new") {
      editContainer = this._renderCreateNew();
    }

    const noTemplatesMessage = (
      <div className="template-status-bar no-templates-message">
        {`You don't have any templates! Enter a template name and press save to create one.`}
      </div>
    );

    return (
      <div className="container-templates">
        <section style={this.state.editState === "new" ? {marginBottom: 50} : null}>
          {editContainer}
          {this.state.editState !== "new" ? editor : null}
          {this.state.templates.length === 0 ? noTemplatesMessage : null}
        </section>

        <section className="templates-instructions">
          <p>
            {`To create a variable, type a set of double curly
            brackets wrapping the variable's name, like this`}: <strong>{"{{"}variable_name{"}}"}</strong>. The highlighting in the variable regions will be removed before the message is
            sent.
          </p>
          <p>
            Reply templates are saved as HTML files in the <strong>~/.nylas-mail/templates</strong> directory on your computer. In raw HTML, variables are defined as HTML &lt;code&gt; tags with class &quot;var empty&quot;.
          </p>
        </section>
      </div>
    );
  }

}

export default PreferencesTemplates;
