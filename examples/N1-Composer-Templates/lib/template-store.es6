import {DraftStore, Actions, QuotedHTMLTransformer} from 'nylas-exports';
import NylasStore from 'nylas-store';
import shell from 'shell';
import path from 'path';
import fs from 'fs';

class TemplateStore extends NylasStore {

  static INVALID_TEMPLATE_NAME_REGEX = /[^a-zA-Z0-9_\- ]+/g;

  constructor() {
    super();
    this._init();
  }

  _init(templatesDir = path.join(NylasEnv.getConfigDirPath(), 'templates')) {
    this.items = this.items.bind(this);
    this.templatesDirectory = this.templatesDirectory.bind(this);
    this._setStoreDefaults = this._setStoreDefaults.bind(this);
    this._registerListeners = this._registerListeners.bind(this);
    this._populate = this._populate.bind(this);
    this._onCreateTemplate = this._onCreateTemplate.bind(this);
    this._onShowTemplates = this._onShowTemplates.bind(this);
    this._displayDialog = this._displayDialog.bind(this);
    this._displayError = this._displayError.bind(this);
    this.saveNewTemplate = this.saveNewTemplate.bind(this);
    this.saveTemplate = this.saveTemplate.bind(this);
    this.deleteTemplate = this.deleteTemplate.bind(this);
    this.renameTemplate = this.renameTemplate.bind(this);
    this.getTemplateContents = this.getTemplateContents.bind(this);
    this._onInsertTemplateId = this._onInsertTemplateId.bind(this);
    this._setStoreDefaults();
    this._registerListeners();

    this._templatesDir = templatesDir;
    this._welcomeName = 'Welcome to Templates.html';
    this._welcomePath = path.join(__dirname, '..', 'assets', this._welcomeName);
    this._watcher = null;

    // I know this is a bit of pain but don't do anything that
    // could possibly slow down app launch
    fs.exists(this._templatesDir, (exists) => {
      if (exists) {
        this._populate();
        this.watch()
      } else {
        fs.mkdir(this._templatesDir, () => {
          fs.readFile(this._welcomePath, (err, welcome) => {
            fs.writeFile(path.join(this._templatesDir, this._welcomeName), welcome, () => {
              this.watch()
            });
          });
        });
      }
    });
  }

  watch() {
    if(!this._watcher)
      this._watcher = fs.watch(this._templatesDir, () => this._populate());
  }
  unwatch() {
    this._watcher.close();
    this._watcher = null;
  }

  items() {
    return this._items;
  }

  templatesDirectory() {
    return this._templatesDir;
  }

  _setStoreDefaults() {
    this._items = [];
  }

  _registerListeners() {
    this.listenTo(Actions.insertTemplateId, this._onInsertTemplateId);
    this.listenTo(Actions.createTemplate, this._onCreateTemplate);
    this.listenTo(Actions.showTemplates, this._onShowTemplates);
  }

  _populate() {
    fs.readdir(this._templatesDir, (err, filenames) => {
      this._items = [];
      for (let i = 0, filename; i < filenames.length; i++) {
        filename = filenames[i];
        if (filename[0] === '.') { continue; }
        const displayname = path.basename(filename, path.extname(filename));
        this._items.push({
          id: filename,
          name: displayname,
          path: path.join(this._templatesDir, filename),
        });
      }
      this.trigger(this);
    });
  }

  _onCreateTemplate({draftClientId, name, contents} = {}) {
    if (draftClientId) {
      DraftStore.sessionForClientId(draftClientId).then((session) => {
        const draft = session.draft();
        const draftName = name ? name : draft.subject.replace(TemplateStore.INVALID_TEMPLATE_NAME_REGEX,"");
        const draftContents = contents ? contents : QuotedHTMLTransformer.removeQuotedHTML(draft.body);
        if (!draftName || draftName.length === 0) {
          this._displayError('Give your draft a subject to name your template.');
        }
        if (!draftContents || draftContents.length === 0) {
          this._displayError('To create a template you need to fill the body of the current draft.');
        }
        this.saveNewTemplate(draftName, draftContents, this._onShowTemplates);
      });
      return;
    }
    if (!name || name.length === 0)
      this._displayError('You must provide a name for your template.');

    if (!contents || contents.length === 0)
      this._displayError('You must provide contents for your template.');

    this.saveNewTemplate(name, contents, this._onShowTemplates);
  }

  _onShowTemplates() {
    Actions.switchPreferencesTab('Quick Replies');
    Actions.openPreferences()
  }

  _displayError(message) {
    const dialog = require('remote').require('dialog');
    dialog.showErrorBox('Template Creation Error', message);
  }
  _displayDialog(title,message,buttons) {
    const dialog = require('remote').require('dialog');
    return 0==dialog.showMessageBox({
          title: title,
          message: title,
          detail: message,
          buttons: buttons,
          type: 'info'
        });
  }

  saveNewTemplate(name, contents, callback) {
    if(name.match(TemplateStore.INVALID_TEMPLATE_NAME_REGEX)) {
      this._displayError("Invalid template name! Names can only contain letters, numbers, spaces, dashes, and underscores.");
      return;
    }

    var template = this._getTemplate(name);
    if(template) {
      this._displayError("A template with that name already exists!");
      return;
    }
    this.saveTemplate(name, contents, callback);
    this.trigger(this);
  }

  _getTemplate(name, id) {
    for(let template of this._items) {
      if((template.name === name || name == null) && (template.id === id || id == null))
        return template;
    }
    return null;
  }

  saveTemplate(name, contents, callback) {
    const filename = `${name}.html`;
    const templatePath = path.join(this._templatesDir, filename);

    var template = this._getTemplate(name);
    this.unwatch();
    fs.writeFile(templatePath, contents, (err) => {
      this.watch();
      if (err) { this._displayError(err); }
      if (template === null) {
        template = {
          id: filename,
          name: name,
          path: templatePath
        };
        this._items.push(template);
      }
      if(callback)
        callback(template);
    });
  }

  deleteTemplate(name, callback) {
    var template = this._getTemplate(name);
    if (!template) { return undefined }

    if(this._displayDialog(
        'Delete this template?',
        'The template and its file will be permanently deleted.',
        ['Delete','Cancel']
    ))
      fs.unlink(template.path, () => {
        this._populate();
        if(callback)
          callback()
      });
  }

  renameTemplate(oldName, newName, callback) {
    if(newName.match(TemplateStore.INVALID_TEMPLATE_NAME_REGEX)) {
      this._displayError("Invalid template name! Names can only contain letters, numbers, spaces, dashes, and underscores.");
      return;
    }
    var template = this._getTemplate(oldName);
    if (!template) { return undefined }

    const newFilename = `${newName}.html`;
    const oldPath = path.join(this._templatesDir, `${oldName}.html`);
    const newPath = path.join(this._templatesDir, newFilename);
    fs.rename(oldPath, newPath, () => {
      template.name = newName;
      template.id = newFilename;
      template.path = newPath;
      this.trigger(this);
      callback(template)
    });
  }

  _onInsertTemplateId({templateId, draftClientId} = {}) {
    this.getTemplateContents(templateId, (body) => {
      DraftStore.sessionForClientId(draftClientId).then((session)=> {
        var proceed = true;
        if (!session.draft().pristine) {
          proceed = this._displayDialog(
              'Replace draft contents?',
              'It looks like your draft already has some content. Loading this template will ' +
              'overwrite all draft contents.',
              ['Replace contents','Cancel']
          )
        }

        if(proceed) {
          draftHtml = QuotedHTMLTransformer.appendQuotedHTML(body, session.draft().body);
          session.changes.add({body: draftHtml});
        }
      });
    });
  }

  getTemplateContents(templateId, callback) {
    var template = this._getTemplate(null,templateId);
    if (!template) { return undefined }

    fs.readFile(template.path, (err, data)=> {
      const body = data.toString();
      callback(body);
    });
  }
}

module.exports = new TemplateStore();
