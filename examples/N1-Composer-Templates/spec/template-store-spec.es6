import fs from 'fs';
import shell from 'shell';
import {Message, DraftStore} from 'nylas-exports';
import TemplateStore from '../lib/template-store';

const stubTemplatesDir = '~/.nylas/templates';

const stubTemplateFiles = {
  'template1.html': '<p>bla1</p>',
  'template2.html': '<p>bla2</p>',
};

const stubTemplates = [
  {id: 'template1.html', name: 'template1', path: `${stubTemplatesDir}/template1.html`},
  {id: 'template2.html', name: 'template2', path: `${stubTemplatesDir}/template2.html`},
];

describe('TemplateStore', ()=> {
  beforeEach(()=> {
    spyOn(fs, 'mkdir');
    spyOn(shell, 'showItemInFolder').andCallFake(()=> {});
    spyOn(fs, 'writeFile').andCallFake((path, contents, callback)=> {
      callback(null);
    });
    spyOn(fs, 'readFile').andCallFake((path, callback)=> {
      const filename = path.split('/').pop();
      callback(null, stubTemplateFiles[filename]);
    });
  });

  it('should create the templates folder if it does not exist', ()=> {
    spyOn(fs, 'exists').andCallFake((path, callback)=> callback(false) );
    TemplateStore.init(stubTemplatesDir);
    expect(fs.mkdir).toHaveBeenCalled();
  });

  it('should expose templates in the templates directory', ()=> {
    let watchCallback;
    spyOn(fs, 'exists').andCallFake((path, callback)=> { callback(true); });
    spyOn(fs, 'watch').andCallFake((path, callback)=> watchCallback = callback);
    spyOn(fs, 'readdir').andCallFake((path, callback)=> { callback(null, Object.keys(stubTemplateFiles)); });
    TemplateStore.init(stubTemplatesDir);
    watchCallback();
    expect(TemplateStore.items()).toEqual(stubTemplates);
  });

  it('should watch the templates directory and reflect changes', ()=> {
    let watchCallback = null;
    let watchFired = false;

    spyOn(fs, 'exists').andCallFake((path, callback)=> callback(true));
    spyOn(fs, 'watch').andCallFake((path, callback)=> watchCallback = callback);
    spyOn(fs, 'readdir').andCallFake((path, callback)=> {
      if (watchFired) {
        callback(null, Object.keys(stubTemplateFiles));
      } else {
        callback(null, []);
      }
    });
    TemplateStore.init(stubTemplatesDir);
    expect(TemplateStore.items()).toEqual([]);

    watchFired = true;
    watchCallback();
    expect(TemplateStore.items()).toEqual(stubTemplates);
  });

  describe('insertTemplateId', ()=> {
    it('should insert the template with the given id into the draft with the given id', ()=> {
      let watchCallback;
      spyOn(fs, 'exists').andCallFake((path, callback)=> { callback(true); });
      spyOn(fs, 'watch').andCallFake((path, callback)=> watchCallback = callback);
      spyOn(fs, 'readdir').andCallFake((path, callback)=> { callback(null, Object.keys(stubTemplateFiles)); });
      TemplateStore.init(stubTemplatesDir);
      watchCallback();
      const add = jasmine.createSpy('add');
      spyOn(DraftStore, 'sessionForClientId').andCallFake(()=> {
        return Promise.resolve({changes: {add}});
      });

      runs(()=> {
        TemplateStore._onInsertTemplateId({
          templateId: 'template1.html',
          draftClientId: 'localid-draft',
        });
      });
      waitsFor(()=> add.calls.length > 0);
      runs(()=> {
        expect(add).toHaveBeenCalledWith({
          body: stubTemplateFiles['template1.html'],
        });
      });
    });
  });

  describe('onCreateTemplate', ()=> {
    beforeEach(()=> {
      let d;
      spyOn(DraftStore, 'sessionForClientId').andCallFake((draftClientId)=> {
        if (draftClientId === 'localid-nosubject') {
          d = new Message({subject: '', body: '<p>Body</p>'});
        } else {
          d = new Message({subject: 'Subject', body: '<p>Body</p>'});
        }
        const session = {draft() { return d; }};
        return Promise.resolve(session);
      });
      TemplateStore.init(stubTemplatesDir);
    });

    it('should create a template with the given name and contents', ()=> {
      const ref = TemplateStore.items();
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'});
      const item = (ref != null ? ref[0] : undefined);
      expect(item.id).toBe('123.html');
      expect(item.name).toBe('123');
      expect(item.path.split('/').pop()).toBe('123.html');
    });

    it('should display an error if no name is provided', ()=> {
      spyOn(TemplateStore, '_displayError');
      TemplateStore._onCreateTemplate({contents: 'bla'});
      expect(TemplateStore._displayError).toHaveBeenCalled();
    });

    it('should display an error if no content is provided', ()=> {
      spyOn(TemplateStore, '_displayError');
      TemplateStore._onCreateTemplate({name: 'bla'});
      expect(TemplateStore._displayError).toHaveBeenCalled();
    });

    it('should save the template file to the templates folder', ()=> {
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'});
      const path = `${stubTemplatesDir}/123.html`;
      expect(fs.writeFile).toHaveBeenCalled();
      expect(fs.writeFile.mostRecentCall.args[0]).toEqual(path);
      expect(fs.writeFile.mostRecentCall.args[1]).toEqual('bla');
    });

    it('should open the template so you can see it', ()=> {
      TemplateStore._onCreateTemplate({name: '123', contents: 'bla'});
      expect(shell.showItemInFolder).toHaveBeenCalled();
    });

    describe('when given a draft id', ()=> {
      it('should create a template from the name and contents of the given draft', ()=> {
        spyOn(TemplateStore, 'trigger');
        spyOn(TemplateStore, '_populate');
        runs(()=> {
          TemplateStore._onCreateTemplate({draftClientId: 'localid-b'});
        });
        waitsFor(()=> TemplateStore.trigger.callCount > 0 );
        runs(()=> {
          expect(TemplateStore.items().length).toEqual(1);
        });
      });

      it('should display an error if the draft has no subject', ()=> {
        spyOn(TemplateStore, '_displayError');
        runs(()=> {
          TemplateStore._onCreateTemplate({draftClientId: 'localid-nosubject'});
        });
        waitsFor(()=> TemplateStore._displayError.callCount > 0 );
        runs(()=> {
          expect(TemplateStore._displayError).toHaveBeenCalled();
        });
      });
    });
  });

  describe('onShowTemplates', ()=> {
    it('should open the templates folder in the Finder', ()=> {
      TemplateStore._onShowTemplates();
      expect(shell.showItemInFolder).toHaveBeenCalled();
    });
  });
});
