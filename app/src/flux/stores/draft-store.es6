import { ipcRenderer } from 'electron';
import MailspringStore from 'mailspring-store';
import DraftEditingSession from './draft-editing-session';
import DraftHelpers from './draft-helpers';
import DraftFactory from './draft-factory';
import DatabaseStore from './database-store';
import SendActionsStore from './send-actions-store';
import FocusedContentStore from './focused-content-store';
import SyncbackDraftTask from '../tasks/syncback-draft-task';
import SendDraftTask from '../tasks/send-draft-task';
import DestroyDraftTask from '../tasks/destroy-draft-task';
import Thread from '../models/thread';
import Message from '../models/message';
import Actions from '../actions';
import TaskQueue from './task-queue';
import MessageBodyProcessor from './message-body-processor';
import SoundRegistry from '../../registries/sound-registry';
import * as ExtensionRegistry from '../../registries/extension-registry';

const { DefaultSendActionKey } = SendActionsStore;
/*
Public: DraftStore responds to Actions that interact with Drafts and exposes
public getter methods to return Draft objects and sessions.

It also creates and queues {Task} objects to persist changes to the Nylas
API.

Remember that a "Draft" is actually just a "Message" with `draft: true`.

Section: Drafts
*/
class DraftStore extends MailspringStore {
  constructor() {
    super();
    this.listenTo(DatabaseStore, this._onDataChanged);
    this.listenTo(Actions.composeReply, this._onComposeReply);
    this.listenTo(Actions.composeForward, this._onComposeForward);
    this.listenTo(Actions.composePopoutDraft, this._onPopoutDraft);
    this.listenTo(Actions.composeNewBlankDraft, this._onPopoutBlankDraft);
    this.listenTo(Actions.composeNewDraftToRecipient, this._onPopoutNewDraftToRecipient);
    this.listenTo(Actions.draftDeliveryFailed, this._onSendDraftFailed);
    this.listenTo(Actions.draftDeliverySucceeded, this._onSendDraftSuccess);
    this.listenTo(Actions.didCancelSendAction, this._onDidCancelSendAction);
    this.listenTo(Actions.sendQuickReply, this._onSendQuickReply);

    if (AppEnv.isMainWindow()) {
      ipcRenderer.on('new-message', () => {
        Actions.composeNewBlankDraft();
      });
    }

    // Remember that these two actions only fire in the current window and
    // are picked up by the instance of the DraftStore in the current
    // window.
    this.listenTo(Actions.sendDraft, this._onSendDraft);
    this.listenTo(Actions.destroyDraft, this._onDestroyDraft);

    AppEnv.onBeforeUnload(this._onBeforeUnload);

    this._draftSessions = {};
    this._draftsSending = {};

    ipcRenderer.on('mailto', this._onHandleMailtoLink);
    ipcRenderer.on('mailfiles', this._onHandleMailFiles);
  }

  /**
  Fetch a {DraftEditingSession} for displaying and/or editing the
  draft with `headerMessageId`.

  @param {String} headerMessageId - The headerMessageId of the draft.
  @returns {Promise} - Resolves to an {DraftEditingSession} for the draft once it has been prepared
  */
  sessionForClientId(headerMessageId) {
    if (!headerMessageId) {
      throw new Error('DraftStore::sessionForClientId requires a headerMessageId');
    }
    if (this._draftSessions[headerMessageId] == null) {
      this._draftSessions[headerMessageId] = this._createSession(headerMessageId);
    }
    return this._draftSessions[headerMessageId].prepare();
  }

  // Public: Look up the sending state of the given draft headerMessageId.
  // In popout windows the existance of the window is the sending state.
  isSendingDraft(headerMessageId) {
    return this._draftsSending[headerMessageId] || false;
  }

  _doneWithSession(session) {
    session.teardown();
    delete this._draftSessions[session.headerMessageId];
  }

  _cleanupAllSessions() {
    Object.values(this._draftSessions).forEach(session => {
      this._doneWithSession(session);
    });
  }

  _onBeforeUnload = readyToUnload => {
    const promises = [];

    // Normally we'd just append all promises, even the ones already
    // fulfilled (nothing to save), but in this case we only want to
    // block window closing if we have to do real work. Calling
    // window.close() within on onbeforeunload could do weird things.
    Object.values(this._draftSessions).forEach(session => {
      const draft = session.draft();
      if (draft && draft.pristine) {
        Actions.queueTask(
          new DestroyDraftTask({
            messageIds: [draft.id],
            accountId: draft.accountId,
          })
        );
      } else {
        promises.push(session.changes.commit());
      }
    });

    if (promises.length > 0) {
      Promise.all(promises).then(() => {
        this._draftSessions = {};
        // We have to wait for accumulateAndTrigger() in the DatabaseStore to
        // send events to ActionBridge before closing the window.
        setTimeout(readyToUnload, 15);
      });

      // Stop and wait before closing
      return false;
    }
    // Continue closing
    return true;
  };

  _onDataChanged = change => {
    if (change.objectClass !== Message.name) {
      return;
    }
    const containsDraft = change.objects.some(msg => msg.draft);
    if (!containsDraft) {
      return;
    }
    this.trigger(change);
  };

  _onSendQuickReply = ({ thread, threadId, message, messageId }, body) => {
    if (AppEnv.config.get('core.sending.sounds')) {
      SoundRegistry.playSound('hit-send');
    }
    return Promise.props(this._modelifyContext({ thread, threadId, message, messageId }))
      .then(({ message: m, thread: t }) => {
        return DraftFactory.createDraftForReply({ message: m, thread: t, type: 'reply' });
      })
      .then(draft => {
        draft.body = `${body}\n\n${draft.body}`;
        draft.pristine = false;

        const t = new SyncbackDraftTask({ draft });
        Actions.queueTask(t);
        TaskQueue.waitForPerformLocal(t).then(() => {
          Actions.sendDraft(draft.headerMessageId);
        });
      });
  };

  _onComposeReply = ({ thread, threadId, message, messageId, popout, type, behavior }) => {
    Actions.recordUserEvent('Draft Created', { type });
    return Promise.props(this._modelifyContext({ thread, threadId, message, messageId }))
      .then(({ message: m, thread: t }) => {
        return DraftFactory.createOrUpdateDraftForReply({ message: m, thread: t, type, behavior });
      })
      .then(draft => {
        return this._finalizeAndPersistNewMessage(draft, { popout });
      });
  };

  _onComposeForward = async ({ thread, threadId, message, messageId, popout }) => {
    Actions.recordUserEvent('Draft Created', { type: 'forward' });
    return Promise.props(this._modelifyContext({ thread, threadId, message, messageId }))
      .then(({ thread: t, message: m }) => {
        return DraftFactory.createDraftForForward({ thread: t, message: m });
      })
      .then(draft => {
        return this._finalizeAndPersistNewMessage(draft, { popout });
      });
  };

  _modelifyContext({ thread, threadId, message, messageId }) {
    const queries = {};
    if (thread) {
      if (!(thread instanceof Thread)) {
        throw new Error(
          'newMessageWithContext: `thread` present, expected a Model. Maybe you wanted to pass `threadId`?'
        );
      }
      queries.thread = thread;
    } else {
      queries.thread = DatabaseStore.find(Thread, threadId);
    }

    if (message) {
      if (!(message instanceof Message)) {
        throw new Error(
          'newMessageWithContext: `message` present, expected a Model. Maybe you wanted to pass `messageId`?'
        );
      }
      queries.message = message;
    } else if (messageId != null) {
      queries.message = DatabaseStore.find(Message, messageId).include(Message.attributes.body);
    } else {
      queries.message = DatabaseStore.findBy(Message, { threadId: threadId || thread.id })
        .order(Message.attributes.date.descending())
        .limit(1)
        .include(Message.attributes.body);
    }

    return queries;
  }

  _finalizeAndPersistNewMessage(draft, { popout } = {}) {
    // Give extensions an opportunity to perform additional setup to the draft
    ExtensionRegistry.Composer.extensions().forEach(extension => {
      if (!extension.prepareNewDraft) {
        return;
      }
      extension.prepareNewDraft({ draft });
    });

    // Optimistically create a draft session and hand it the draft so that it
    // doesn't need to do a query for it a second from now when the composer wants it.
    this._createSession(draft.headerMessageId, draft);

    const task = new SyncbackDraftTask({ draft });
    Actions.queueTask(task);

    return TaskQueue.waitForPerformLocal(task).then(() => {
      if (popout) {
        this._onPopoutDraft(draft.headerMessageId);
      } else {
        Actions.focusDraft({ headerMessageId: draft.headerMessageId });
      }
      return { headerMessageId: draft.headerMessageId, draft };
    });
  }

  _createSession(headerMessageId, draft) {
    this._draftSessions[headerMessageId] = new DraftEditingSession(headerMessageId, draft);
    return this._draftSessions[headerMessageId];
  }

  _onPopoutNewDraftToRecipient = async contact => {
    const draft = await DraftFactory.createDraft({ to: [contact] });
    await this._finalizeAndPersistNewMessage(draft, { popout: true });
  };

  _onPopoutBlankDraft = async () => {
    Actions.recordUserEvent('Draft Created', { type: 'new' });
    const draft = await DraftFactory.createDraft();
    const { headerMessageId } = await this._finalizeAndPersistNewMessage(draft);
    await this._onPopoutDraft(headerMessageId, { newDraft: true });
  };

  _onPopoutDraft = async (headerMessageId, options = {}) => {
    if (headerMessageId == null) {
      throw new Error('DraftStore::onPopoutDraftId - You must provide a headerMessageId');
    }

    const session = await this.sessionForClientId(headerMessageId);
    await session.changes.commit();
    const draftJSON = session.draft().toJSON();

    // Since we pass a windowKey, if the popout composer draft already
    // exists we'll simply show that one instead of spawning a whole new
    // window.
    AppEnv.newWindow({
      hidden: true, // We manually show in ComposerWithWindowProps::onDraftReady
      windowType: 'composer',
      windowKey: `composer-${headerMessageId}`,
      windowProps: Object.assign(options, { headerMessageId, draftJSON }),
      title: options.newDraft ? 'New Message' : 'Message',
    });
  };

  _onHandleMailtoLink = async (event, urlString) => {
    // returned promise is just used for specs
    const draft = await DraftFactory.createDraftForMailto(urlString);
    try {
      await this._finalizeAndPersistNewMessage(draft, { popout: true });
    } catch (err) {
      AppEnv.showErrorDialog(err.toString());
    }
  };

  _onHandleMailFiles = async (event, paths) => {
    // returned promise is just used for specs
    const draft = await DraftFactory.createDraft();
    const { headerMessageId } = await this._finalizeAndPersistNewMessage(draft);

    let remaining = paths.length;
    const callback = () => {
      remaining -= 1;
      if (remaining === 0) {
        this._onPopoutDraft(headerMessageId);
      }
    };

    paths.forEach(path => {
      Actions.addAttachment({
        filePath: path,
        headerMessageId: headerMessageId,
        onCreated: callback,
      });
    });
  };

  _onDestroyDraft = ({ accountId, headerMessageId, id }) => {
    const session = this._draftSessions[headerMessageId];

    // Immediately reset any pending changes so no saves occur
    if (session) {
      this._doneWithSession(session);
    }

    // Stop any pending tasks related to the draft
    TaskQueue.queue().forEach(task => {
      if (task instanceof SyncbackDraftTask && task.headerMessageId === headerMessageId) {
        Actions.cancelTask(task);
      }
      if (task instanceof SendDraftTask && task.headerMessageId === headerMessageId) {
        Actions.cancelTask(task);
      }
    });

    // Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask({ accountId, messageIds: [id] }));

    if (AppEnv.isComposerWindow()) {
      AppEnv.close();
    }
  };

  _onSendDraft = async (headerMessageId, sendActionKey = DefaultSendActionKey) => {
    this._draftsSending[headerMessageId] = true;

    const sendAction = SendActionsStore.sendActionForKey(sendActionKey);
    if (!sendAction) {
      throw new Error(`Cant find send action ${sendActionKey} `);
    }

    // get the draft session, apply any last-minute edits and get the final draft.
    // We need to call `changes.commit` here to ensure the body of the draft is
    // completely saved and the user won't see old content briefly.
    const session = await this.sessionForClientId(headerMessageId);
    await session.ensureCorrectAccount();
    let draft = session.draft();
    console.log('1:');
    console.log(JSON.stringify(draft));
    await session.changes.commit();
    console.log('2:');
    console.log(JSON.stringify(session.draft()));
    await session.teardown();

    draft = await DraftHelpers.applyExtensionTransforms(draft);
    draft = await DraftHelpers.pruneRemovedInlineFiles(draft);
    if (draft.replyToHeaderMessageId && DraftHelpers.shouldAppendQuotedText(draft)) {
      draft = await DraftHelpers.appendQuotedTextToDraft(draft);
    }

    // Directly update the message body cache so the user immediately sees
    // the new message text (and never old draft text or blank text) sending.
    await MessageBodyProcessor.updateCacheForMessage(draft);

    console.log('3:');
    console.log(JSON.stringify(draft));

    // At this point the message UI enters the sending state and the composer is unmounted.
    this.trigger({ headerMessageId });

    // Now do the actual sending!
    await sendAction.performSendAction({ draft });
    this._doneWithSession(session);

    if (AppEnv.isComposerWindow()) {
      AppEnv.close();
    }
  };

  _onDidCancelSendAction = ({ headerMessageId }) => {
    delete this._draftsSending[headerMessageId];
    this.trigger({ headerMessageId });
  };

  _onSendDraftSuccess = ({ headerMessageId }) => {
    delete this._draftsSending[headerMessageId];
    this.trigger({ headerMessageId });
  };

  _onSendDraftFailed = ({ headerMessageId, threadId, errorMessage, errorDetail }) => {
    this._draftsSending[headerMessageId] = false;
    this.trigger({ headerMessageId });

    if (AppEnv.isMainWindow()) {
      // We delay so the view has time to update the restored draft. If we
      // don't delay the modal may come up in a state where the draft looks
      // like it hasn't been restored or has been lost.
      //
      // We also need to delay because the old draft window needs to fully
      // close. It takes windows currently (June 2016) 100ms to close by
      setTimeout(() => {
        const focusedThread = FocusedContentStore.focused('thread');
        if (threadId && focusedThread && focusedThread.id === threadId) {
          AppEnv.showErrorDialog(errorMessage, { detail: errorDetail });
        } else {
          Actions.composePopoutDraft(headerMessageId, { errorMessage, errorDetail });
        }
      }, 300);
    }
  };
}

export default new DraftStore();
