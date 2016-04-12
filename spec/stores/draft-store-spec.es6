import {
  Thread,
  Actions,
  Contact,
  Message,
  Account,
  DraftStore,
  DatabaseStore,
  SoundRegistry,
  SendDraftTask,
  DestroyDraftTask,
  ComposerExtension,
  ExtensionRegistry,
  FocusedContentStore,
  DatabaseTransaction,
  SyncbackDraftFilesTask,
} from 'nylas-exports';

import DraftFactory from '../../src/flux/stores/draft-factory';

class TestExtension extends ComposerExtension {
  static prepareNewDraft({draft}) {
    draft.body = "Edited by TestExtension!" + draft.body;
  }
}

describe("DraftStore", () => {
  beforeEach(() => {
    this.fakeThread = new Thread({id: 'fake-thread', clientId: 'fake-thread'});
    this.fakeMessage = new Message({id: 'fake-message', clientId: 'fake-message'});

    spyOn(NylasEnv, 'newWindow').andCallFake(() => {});
    spyOn(DatabaseTransaction.prototype, "persistModel").andReturn(Promise.resolve());
    spyOn(DatabaseStore, 'run').andCallFake((query) => {
      if (query._klass === Thread) { return Promise.resolve(this.fakeThread); }
      if (query._klass === Message) { return Promise.resolve(this.fakeMessage); }
      if (query._klass === Contact) { return Promise.resolve(null); }
      return Promise.reject(new Error(`Not Stubbed for class ${query._klass.name}`));
    });

    for (const draftClientId of Object.keys(DraftStore._draftSessions)) {
      const sess = DraftStore._draftSessions[draftClientId];
      if (sess.teardown) {
        DraftStore._doneWithSession(sess);
      }
    }
    DraftStore._draftSessions = {};
  });

  describe("creating and opening drafts", () => {
    beforeEach(() => {
      const draft = new Message({id: "A", subject: "B", clientId: "A", body: "123"});
      this.newDraft = draft;
      spyOn(DraftFactory, "createDraftForReply").andReturn(Promise.resolve(draft));
      spyOn(DraftFactory, "createOrUpdateDraftForReply").andReturn(Promise.resolve(draft));
      spyOn(DraftFactory, "createDraftForForward").andReturn(Promise.resolve(draft));
      spyOn(DraftFactory, "createDraft").andReturn(Promise.resolve(draft));
    });

    it("should always attempt to focus the new draft", () => {
      spyOn(Actions, 'focusDraft')
      DraftStore._onComposeReply({
        threadId: this.fakeThread.id,
        messageId: this.fakeMessage.id,
        type: 'reply',
        behavior: 'prefer-existing',
      });
      advanceClock();
      advanceClock();
      expect(Actions.focusDraft).toHaveBeenCalled();
    });

    describe("context", () => {
      it("can accept IDs for thread and message arguments", () => {
        DraftStore._onComposeReply({
          threadId: this.fakeThread.id,
          messageId: this.fakeMessage.id,
          type: 'reply',
          behavior: 'prefer-existing',
        });
        advanceClock();
        expect(DraftFactory.createOrUpdateDraftForReply).toHaveBeenCalledWith({
          thread: this.fakeThread,
          message: this.fakeMessage,
          type: 'reply',
          behavior: 'prefer-existing',
        });
      });

      it("can accept models for thread and message arguments", () => {
        DraftStore._onComposeReply({
          thread: this.fakeThread,
          message: this.fakeMessage,
          type: 'reply',
          behavior: 'prefer-existing',
        });
        advanceClock();
        expect(DraftFactory.createOrUpdateDraftForReply).toHaveBeenCalledWith({
          thread: this.fakeThread,
          message: this.fakeMessage,
          type: 'reply',
          behavior: 'prefer-existing',
        });
      });

      it("can accept only a thread / threadId, and use the last message on the thread", () => {
        DraftStore._onComposeReply({
          thread: this.fakeThread,
          type: 'reply',
          behavior: 'prefer-existing',
        });
        advanceClock();
        expect(DraftFactory.createOrUpdateDraftForReply).toHaveBeenCalledWith({
          thread: this.fakeThread,
          message: this.fakeMessage,
          type: 'reply',
          behavior: 'prefer-existing',
        });
      });
    });

    describe("popout behavior", () => {
      it("can popout a reply", () => {
        runs(() => {
          DraftStore._onComposeReply({
            threadId: this.fakeThread.id,
            messageId: this.fakeMessage.id,
            type: 'reply',
            popout: true}
          );
        });
        waitsFor(() => {
          return DatabaseTransaction.prototype.persistModel.callCount > 0;
        });
        runs(() => {
          expect(NylasEnv.newWindow).toHaveBeenCalledWith({
            title: 'Message',
            windowType: "composer",
            windowProps: { draftClientId: "A", draftJSON: this.newDraft.toJSON() },
          });
        });
      });

      it("can popout a forward", () => {
        runs(() => {
          DraftStore._onComposeForward({
            threadId: this.fakeThread.id,
            messageId: this.fakeMessage.id,
            popout: true,
          });
        });
        waitsFor(() => {
          return DatabaseTransaction.prototype.persistModel.callCount > 0;
        });
        runs(() => {
          expect(NylasEnv.newWindow).toHaveBeenCalledWith({
            title: 'Message',
            windowType: "composer",
            windowProps: { draftClientId: "A", draftJSON: this.newDraft.toJSON() },
          });
        });
      });
    });
  });

  describe("onDestroyDraft", () => {
    beforeEach(() => {
      this.draftSessionTeardown = jasmine.createSpy('draft teardown');
      this.session =
        {draft() {
          return {pristine: false};
        },
        changes:
          {commit() { return Promise.resolve(); },
          teardown() {},
          },
        teardown: this.draftSessionTeardown,
        };
      DraftStore._draftSessions = {"abc": this.session};
      spyOn(Actions, 'queueTask');
    });

    it("should teardown the draft session, ensuring no more saves are made", () => {
      DraftStore._onDestroyDraft('abc');
      expect(this.draftSessionTeardown).toHaveBeenCalled();
    });

    it("should not throw if the draft session is not in the window", () => {
      expect(() => DraftStore._onDestroyDraft('other')).not.toThrow();
    });

    it("should queue a destroy draft task", () => {
      DraftStore._onDestroyDraft('abc');
      expect(Actions.queueTask).toHaveBeenCalled();
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true);
    });

    it("should clean up the draft session", () => {
      spyOn(DraftStore, '_doneWithSession');
      DraftStore._onDestroyDraft('abc');
      expect(DraftStore._doneWithSession).toHaveBeenCalledWith(this.session);
    });

    it("should close the window if it's a popout", () => {
      spyOn(NylasEnv, "close");
      spyOn(DraftStore, "_isPopout").andReturn(true);
      DraftStore._onDestroyDraft('abc');
      expect(NylasEnv.close).toHaveBeenCalled();
    });

    it("should NOT close the window if isn't a popout", () => {
      spyOn(NylasEnv, "close");
      spyOn(DraftStore, "_isPopout").andReturn(false);
      DraftStore._onDestroyDraft('abc');
      expect(NylasEnv.close).not.toHaveBeenCalled();
    });
  });

  describe("before unloading", () => {
    it("should destroy pristine drafts", () => {
      DraftStore._draftSessions = {"abc": {
        changes: {},
        draft() {
          return {pristine: true};
        },
      }};

      spyOn(Actions, 'queueTask');
      DraftStore._onBeforeUnload();
      expect(Actions.queueTask).toHaveBeenCalled();
      expect(Actions.queueTask.mostRecentCall.args[0] instanceof DestroyDraftTask).toBe(true);
    });

    describe("when drafts return unresolved commit promises", () => {
      beforeEach(() => {
        this.resolve = null;
        DraftStore._draftSessions = {
          "abc": {
            changes: {
              commit: () => new Promise((resolve) => this.resolve = resolve),
            },
            draft() {
              return {pristine: false};
            },
          },
        };
      });

      it("should return false and call window.close itself", () => {
        const callback = jasmine.createSpy('callback');
        expect(DraftStore._onBeforeUnload(callback)).toBe(false);
        expect(callback).not.toHaveBeenCalled();
        this.resolve();
        advanceClock(1000);
        expect(callback).toHaveBeenCalled();
      });
    });

    describe("when drafts return immediately fulfilled commit promises", () => {
      beforeEach(() => {
        DraftStore._draftSessions = {"abc": {
          changes:
            {commit: () => Promise.resolve()},
          draft() {
            return {pristine: false};
          },
        }};
      });

      it("should still wait one tick before firing NylasEnv.close again", () => {
        const callback = jasmine.createSpy('callback');
        expect(DraftStore._onBeforeUnload(callback)).toBe(false);
        expect(callback).not.toHaveBeenCalled();
        advanceClock();
        expect(callback).toHaveBeenCalled();
      });
    });

    describe("when there are no drafts", () => {
      beforeEach(() => {
        DraftStore._draftSessions = {};
      });

      it("should return true and allow the window to close", () => {
        expect(DraftStore._onBeforeUnload()).toBe(true);
      });
    });
  });

  describe("sending a draft", () => {
    beforeEach(() => {
      this.draft = new Message({
        clientId: "local-123",
        threadId: "thread-123",
        replyToMessageId: "message-123",
        uploads: ['stub'],
      });
      DraftStore._draftSessions = {};
      DraftStore._draftsSending = {};
      this.forceCommit = false;
      const proxy = {
        prepare() {
          return Promise.resolve(proxy);
        },
        teardown() {},
        draft: () => this.draft,
        changes: {
          commit: ({force} = {}) => {
            this.forceCommit = force;
            return Promise.resolve();
          },
        },
      };

      DraftStore._draftSessions[this.draft.clientId] = proxy;
      spyOn(DraftStore, "_doneWithSession").andCallThrough();
      spyOn(DraftStore, "_prepareForSyncback").andReturn(Promise.resolve());
      spyOn(DraftStore, "trigger");
      spyOn(SoundRegistry, "playSound");
      spyOn(Actions, "queueTask");
    });

    it("plays a sound immediately when sending draft", () => {
      spyOn(NylasEnv.config, "get").andReturn(true);
      DraftStore._onSendDraft(this.draft.clientId);
      advanceClock();
      expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds");
      expect(SoundRegistry.playSound).toHaveBeenCalledWith("hit-send");
    });

    it("doesn't plays a sound if the setting is off", () => {
      spyOn(NylasEnv.config, "get").andReturn(false);
      DraftStore._onSendDraft(this.draft.clientId);
      advanceClock();
      expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds");
      expect(SoundRegistry.playSound).not.toHaveBeenCalled();
    });

    it("sets the sending state when sending", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      DraftStore._onSendDraft(this.draft.clientId);
      advanceClock();
      expect(DraftStore.isSendingDraft(this.draft.clientId)).toBe(true);
    });

    // Since all changes haven't been applied yet, we want to ensure that
    // no view of the draft renders the draft as if its sending, but with
    // the wrong text.
    it("does NOT trigger until the latest changes have been applied", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      runs(() => {
        DraftStore._onSendDraft(this.draft.clientId);
        expect(DraftStore.trigger).not.toHaveBeenCalled();
      });
      waitsFor(() => {
        return Actions.queueTask.calls.length > 0;
      });
      runs(() => {
        // Normally, the session.changes.commit will persist to the
        // Database. Since that's stubbed out, we need to manually invoke
        // to database update event to get the trigger (which we want to
        // test) to fire
        DraftStore._onDataChanged({
          objectClass: "Message",
          objects: [{draft: true}],
        });
        expect(DraftStore.isSendingDraft(this.draft.clientId)).toBe(true);
        expect(DraftStore.trigger).toHaveBeenCalled();
        expect(DraftStore.trigger.calls.length).toBe(1);
      });
    });

    it("returns false if the draft hasn't been seen", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      expect(DraftStore.isSendingDraft(this.draft.clientId)).toBe(false);
    });

    it("closes the window if it's a popout", () => {
      spyOn(NylasEnv, "getWindowType").andReturn("composer");
      spyOn(NylasEnv, "isMainWindow").andReturn(false);
      spyOn(NylasEnv, "close");
      runs(() => {
        return DraftStore._onSendDraft(this.draft.clientId);
      });
      waitsFor("N1 to close", () => NylasEnv.close.calls.length > 0);
    });

    it("doesn't close the window if it's inline", () => {
      spyOn(NylasEnv, "getWindowType").andReturn("other");
      spyOn(NylasEnv, "isMainWindow").andReturn(false);
      spyOn(NylasEnv, "close");
      spyOn(DraftStore, "_isPopout").andCallThrough();
      runs(() => {
        DraftStore._onSendDraft(this.draft.clientId);
      });
      waitsFor(() => DraftStore._isPopout.calls.length > 0);
      runs(() => {
        expect(NylasEnv.close).not.toHaveBeenCalled();
      });
    });

    it("queues tasks to upload files and send the draft", () => {
      runs(() => {
        DraftStore._onSendDraft(this.draft.clientId);
      });
      waitsFor(() => Actions.queueTask.calls.length > 0);
      runs(() => {
        const saveAttachments = Actions.queueTask.calls[0].args[0];
        expect(saveAttachments instanceof SyncbackDraftFilesTask).toBe(true);
        expect(saveAttachments.draftClientId).toBe(this.draft.clientId);
        const sendDraft = Actions.queueTask.calls[1].args[0];
        expect(sendDraft instanceof SendDraftTask).toBe(true);
        expect(sendDraft.draftClientId).toBe(this.draft.clientId);
      });
    });

    it("resets the sending state if there's an error", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(false);
      DraftStore._draftsSending[this.draft.clientId] = true;
      Actions.draftSendingFailed({errorMessage: "boohoo", draftClientId: this.draft.clientId});
      expect(DraftStore.isSendingDraft(this.draft.clientId)).toBe(false);
      expect(DraftStore.trigger).toHaveBeenCalledWith(this.draft.clientId);
    });

    it("displays a popup in the main window if there's an error", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      spyOn(FocusedContentStore, "focused").andReturn({id: "t1"});
      const {remote} = require('electron');
      spyOn(remote.dialog, "showMessageBox");
      spyOn(Actions, "composePopoutDraft");
      DraftStore._draftsSending[this.draft.clientId] = true;
      Actions.draftSendingFailed({threadId: 't1', errorMessage: "boohoo", draftClientId: this.draft.clientId});
      advanceClock(200);
      expect(DraftStore.isSendingDraft(this.draft.clientId)).toBe(false);
      expect(DraftStore.trigger).toHaveBeenCalledWith(this.draft.clientId);
      expect(remote.dialog.showMessageBox).toHaveBeenCalled();
      const dialogArgs = remote.dialog.showMessageBox.mostRecentCall.args[1];
      expect(dialogArgs.detail).toEqual("boohoo");
      expect(Actions.composePopoutDraft).not.toHaveBeenCalled();
    });

    it("re-opens the draft if you're not looking at the thread", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      spyOn(FocusedContentStore, "focused").andReturn({id: "t1"});
      spyOn(Actions, "composePopoutDraft");
      DraftStore._draftsSending[this.draft.clientId] = true;
      Actions.draftSendingFailed({threadId: 't2', errorMessage: "boohoo", draftClientId: this.draft.clientId});
      advanceClock(200);
      expect(Actions.composePopoutDraft).toHaveBeenCalled();
      const call = Actions.composePopoutDraft.calls[0];
      expect(call.args[0]).toBe(this.draft.clientId);
      expect(call.args[1]).toEqual({errorMessage: "boohoo"});
    });

    it("re-opens the draft if there is no thread id", () => {
      spyOn(NylasEnv, "isMainWindow").andReturn(true);
      spyOn(Actions, "composePopoutDraft");
      DraftStore._draftsSending[this.draft.clientId] = true;
      spyOn(FocusedContentStore, "focused").andReturn(null);
      Actions.draftSendingFailed({errorMessage: "boohoo", draftClientId: this.draft.clientId});
      advanceClock(200);
      expect(Actions.composePopoutDraft).toHaveBeenCalled();
      const call = Actions.composePopoutDraft.calls[0];
      expect(call.args[0]).toBe(this.draft.clientId);
      expect(call.args[1]).toEqual({errorMessage: "boohoo"});
    });
  });

  describe("session teardown", () => {
    beforeEach(() => {
      spyOn(NylasEnv, 'isMainWindow').andReturn(true);
      this.draftTeardown = jasmine.createSpy('draft teardown');
      this.session = {
        draftClientId: "abc",
        draft() {
          return {pristine: false};
        },
        changes: {
          commit() { return Promise.resolve(); },
          reset() {},
        },
        teardown: this.draftTeardown,
      };
      DraftStore._draftSessions = {"abc": this.session};
      DraftStore._doneWithSession(this.session);
    });

    it("removes from the list of draftSessions", () => {
      expect(DraftStore._draftSessions.abc).toBeUndefined();
    });

    it("Calls teardown on the session", () => {
      expect(this.draftTeardown).toHaveBeenCalled();
    });
  });

  describe("mailto handling", () => {
    beforeEach(() => {
      spyOn(NylasEnv, 'isMainWindow').andReturn(true);
    });

    describe("extensions", () => {
      beforeEach(() => {
        ExtensionRegistry.Composer.register(TestExtension);
      });
      afterEach(() => {
        ExtensionRegistry.Composer.unregister(TestExtension);
      });

      it("should give extensions a chance to customize the draft via ext.prepareNewDraft", () => {
        waitsForPromise(() => {
          return DraftStore._onHandleMailtoLink({}, 'mailto:bengotow@gmail.com').then(() => {
            const received = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0];
            expect(received.body.indexOf("Edited by TestExtension!")).toBe(0);
          });
        });
      });
    });

    it("should call through to DraftFactory and popout a new draft", () => {
      const draft = new Message({clientId: "A", body: '123'});
      spyOn(DraftFactory, 'createDraftForMailto').andReturn(Promise.resolve(draft));
      spyOn(DraftStore, '_onPopoutDraftClientId');
      waitsForPromise(() => {
        return DraftStore._onHandleMailtoLink({}, 'mailto:bengotow@gmail.com').then(() => {
          const received = DatabaseTransaction.prototype.persistModel.mostRecentCall.args[0];
          expect(received).toEqual(draft);
          expect(DraftStore._onPopoutDraftClientId).toHaveBeenCalled();
        });
      });
    });
  });

  describe("mailfiles handling", () => {
    it("should popout a new draft", () => {
      const defaultMe = new Contact();
      spyOn(DraftStore, '_onPopoutDraftClientId');
      spyOn(Account.prototype, 'defaultMe').andReturn(defaultMe);
      spyOn(Actions, 'addAttachment');
      DraftStore._onHandleMailFiles({}, ['/Users/ben/file1.png', '/Users/ben/file2.png']);
      waitsFor(() => DatabaseTransaction.prototype.persistModel.callCount > 0);
      runs(() => {
        const {body, subject, from} = DatabaseTransaction.prototype.persistModel.calls[0].args[0];
        expect({body, subject, from}).toEqual({body: '', subject: '', from: [defaultMe]});
        expect(DraftStore._onPopoutDraftClientId).toHaveBeenCalled();
      });
    });

    it("should call addAttachment for each provided file path", () => {
      spyOn(Actions, 'addAttachment');
      DraftStore._onHandleMailFiles({}, ['/Users/ben/file1.png', '/Users/ben/file2.png']);
      waitsFor(() => Actions.addAttachment.callCount === 2);
      runs(() => {
        expect(Actions.addAttachment.calls[0].args[0].filePath).toEqual('/Users/ben/file1.png');
        expect(Actions.addAttachment.calls[1].args[0].filePath).toEqual('/Users/ben/file2.png');
      });
    });
  });
});
