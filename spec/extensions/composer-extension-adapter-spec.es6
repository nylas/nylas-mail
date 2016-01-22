import * as adapter from '../../src/extensions/composer-extension-adapter';
import {DOMUtils} from 'nylas-exports';

const selection = 'selection';
const node = 'node';
const event = 'event';
const extra = 'extra';
const editor = {
  rootNode: node,
  currentSelection() {
    return selection;
  },
};

describe('ComposerExtensionAdapter', ()=> {
  describe('adaptOnInput', ()=> {
    it('adapts correctly if onContentChanged already defined', ()=> {
      const onInputSpy = jasmine.createSpy('onInput');
      const extension = {
        onContentChanged() {},
        onInput(ev, editableNode, sel) {
          onInputSpy(ev, editableNode, sel);
        },
      };
      adapter.adaptOnInput(extension);
      extension.onContentChanged({editor, mutations: []});
      expect(onInputSpy).not.toHaveBeenCalled();
    });

    it('adapts correctly when signature is (event, ...)', ()=> {
      const onInputSpy = jasmine.createSpy('onInput');
      const extension = {
        onInput(ev, editableNode, sel) {
          onInputSpy(ev, editableNode, sel);
        },
      };
      adapter.adaptOnInput(extension);
      expect(extension.onContentChanged).toBeDefined();
      extension.onContentChanged({editor, mutations: []});
      expect(onInputSpy).toHaveBeenCalledWith([], node, selection);
    });

    it('adapts correctly when signature is (editableNode, selection, ...)', ()=> {
      const onInputSpy = jasmine.createSpy('onInput');
      const extension = {
        onInput(editableNode, sel, ev) {
          onInputSpy(editableNode, sel, ev);
        },
      };
      adapter.adaptOnInput(extension);
      expect(extension.onContentChanged).toBeDefined();
      extension.onContentChanged({editor, mutations: []});
      expect(onInputSpy).toHaveBeenCalledWith(node, selection, []);
    });
  });

  describe('adaptOnTabDown', ()=> {
    it('adapts onTabDown correctly', ()=> {
      const onTabDownSpy = jasmine.createSpy('onTabDownSpy');
      const mockEvent = {key: 'Tab'};
      const range = 'range';
      spyOn(DOMUtils, 'getRangeInScope').andReturn(range);
      const extension = {
        onTabDown(editableNode, rn, ev) {
          onTabDownSpy(editableNode, rn, ev);
        },
      };
      adapter.adaptOnTabDown(extension, 'method');
      expect(extension.onKeyDown).toBeDefined();
      extension.onKeyDown({editor, event: mockEvent});
      expect(onTabDownSpy).toHaveBeenCalledWith(node, range, mockEvent);
    });
  });

  describe('adaptContenteditableMethod', ()=> {
    it('adapts correctly when signature is (editor, ...)', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const extension = {
        method(editor, ev, other) {
          methodSpy(editor, ev, other);
        },
      };
      adapter.adaptContenteditableMethod(extension, 'method');
      extension.method({editor, event, extra});
      expect(methodSpy).toHaveBeenCalledWith(editor, event, extra);
    });

    it('adapts correctly when signature is (event, ...)', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const extension = {
        method(ev, editableNode, sel, other) {
          methodSpy(ev, editableNode, sel, other);
        },
      };
      adapter.adaptContenteditableMethod(extension, 'method');
      extension.method({editor, event, extra});
      expect(methodSpy).toHaveBeenCalledWith(event, node, selection, extra);
    });

    it('adapts correctly when signature is (editableNode, selection, ...)', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const extension = {
        method(editableNode, sel, ev, other) {
          methodSpy(editableNode, sel, ev, other);
        },
      };
      adapter.adaptContenteditableMethod(extension, 'method');
      extension.method({editor, event, extra});
      expect(methodSpy).toHaveBeenCalledWith(node, selection, event, extra);
    });

    it('adapts correctly when using mutations instead of an event', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const extension = {
        method(editor, mutations) {
          methodSpy(editor, mutations);
        },
      };
      adapter.adaptContenteditableMethod(extension, 'method');
      extension.method({editor, mutations: []});
      expect(methodSpy).toHaveBeenCalledWith(editor, []);
    });
  });

  describe('adaptComposerMethod', ()=> {
    it('adapts correctly for finalizeSessionBeforeSending', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const session = 'session';
      const extension = {
        finalizeSessionBeforeSending(sess) {
          methodSpy(sess);
          return 'result';
        },
      };
      adapter.adaptComposerMethod(extension, 'finalizeSessionBeforeSending');
      const res = extension.finalizeSessionBeforeSending({session});
      expect(res).toEqual('result');
      expect(methodSpy).toHaveBeenCalledWith(session);
    });

    it('adapts correctly for other composer extension methods', ()=> {
      const methodSpy = jasmine.createSpy('methodSpy');
      const draft = 'draft';
      const extension = {
        warningsForSending(dr) {
          methodSpy(dr);
          return 'result';
        },
      };
      adapter.adaptComposerMethod(extension, 'warningsForSending');
      const res = extension.warningsForSending({draft});
      expect(res).toEqual('result');
      expect(methodSpy).toHaveBeenCalledWith(draft);
    });
  });
});
