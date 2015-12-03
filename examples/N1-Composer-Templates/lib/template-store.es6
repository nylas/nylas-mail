import {DraftStore, Actions, QuotedHTMLParser} from 'nylas-exports';
import NylasStore from 'nylas-store';
import shell from 'shell';
import path from 'path';
import fs from 'fs';

class TemplateStore extends NylasStore {

  init(templatesDir = path.join(NylasEnv.getConfigDirPath(), 'templates')) {
    this.items = this.items.bind(this);
    this.templatesDirectory = this.templatesDirectory.bind(this);
    this._setStoreDefaults = this._setStoreDefaults.bind(this);
    this._registerListeners = this._registerListeners.bind(this);
    this._populate = this._populate.bind(this);
    this._onCreateTemplate = this._onCreateTemplate.bind(this);
    this._onShowTemplates = this._onShowTemplates.bind(this);
    this._displayError = this._displayError.bind(this);
    this._writeTemplate = this._writeTemplate.bind(this);
    this._onInsertTemplateId = this._onInsertTemplateId.bind(this);
    this._setStoreDefaults();
    this._registerListeners();

    this._templatesDir = templatesDir;
    this._welcomeName = 'Welcome to Templates.html';
    this._welcomePath = path.join(__dirname, '..', 'assets', this._welcomeName);

    // I know this is a bit of pain but don't do anything that
    // could possibly slow down app launch
    fs.exists(this._templatesDir, (exists) => {
      if (exists) {
        this._populate();
        fs.watch(this._templatesDir, () => this._populate());
      } else {
        fs.mkdir(this._templatesDir, () => {
          fs.readFile(this._welcomePath, (err, welcome) => {
            fs.writeFile(path.join(this._templatesDir, this._welcomeName), welcome, () => {
              fs.watch(this._templatesDir, () => this._populate());
            });
          });
        });
      }
    });
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
        const draftName = name ? name : draft.subject;
        const draftContents = contents ? contents : QuotedHTMLParser.removeQuotedHTML(draft.body);
        if (!draftName || draftName.length === 0) {
          this._displayError('Give your draft a subject to name your template.');
        }
        if (!draftContents || draftContents.length === 0) {
          this._displayError('To create a template you need to fill the body of the current draft.');
        }
        this._writeTemplate(draftName, draftContents);
      });
      return;
    }
    if (!name || name.length === 0) {
      this._displayError('You must provide a name for your template.');
    }
    if (!contents || contents.length === 0) {
      this._displayError('You must provide contents for your template.');
    }
    this._writeTemplate(name, contents);
  }

  _onShowTemplates() {
    const ref = this._items[0];
    shell.showItemInFolder(((ref != null) ? ref.path : undefined) || this._templatesDir);
  }

  _displayError(message) {
    const dialog = require('remote').require('dialog');
    dialog.showErrorBox('Template Creation Error', message);
  }

  _writeTemplate(name, contents) {
    this.saveTemplate(name, contents, true, (template) => {
      Actions.switchPreferencesTab('Quick Replies');
      Actions.openPreferences()
    });
  }

  saveTemplate(name, contents, isNew, callback) {
    const filename = `${name}.html`;
    const templatePath = path.join(this._templatesDir, filename);

    var template = null;
    this._items.forEach((item) => {
      if (item.name === name) { template = item; }
    });

    if(isNew && template !== null) {
      this._displayError("A template with that name already exists!");
      return undefined;
    }

    fs.writeFile(templatePath, contents, (err) => {
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
      this.trigger(this);
    });
  }

  deleteTemplate(name, callback) {
    var template = null;
    this._items.forEach((item) => {
      if (item.name === name) { template = item; }
    });
    if (!template) { return undefined }

    fs.unlink(template.path, () => {
      this._populate();
      if(callback)
        callback()
    });
  }

  renameTemplate(oldName, newName, callback) {
    var template = null;
    this._items.forEach((item) => {
      if (item.name === oldName) { template = item; }
    });
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
        draftHtml = QuotedHTMLParser.appendQuotedHTML(body, session.draft().body);
        session.changes.add({body: draftHtml});
      });
    });
  }

  getTemplateContents(templateId, callback) {
    let template = null;
    this._items.forEach((item) => {
      if (item.id === templateId) { template = item; }
    });

    if (!template) { return undefined }

    fs.readFile(template.path, (err, data)=> {
      const body = data.toString();
      callback(body);
    });
  }
}

module.exports = new TemplateStore();
