import _ from 'underscore';
import {ipcRenderer} from 'electron';
import NylasStore from 'nylas-store';
import DraftEditingSession from './draft-editing-session';
import DraftHelpers from './draft-helpers';
import DraftFactory from './draft-factory';
import DatabaseStore from './database-store';
import SendActionsStore from './send-actions-store';
import TaskQueueStatusStore from './task-queue-status-store';
import FocusedContentStore from './focused-content-store';
import BaseDraftTask from '../tasks/base-draft-task';
import PerformSendActionTask from '../tasks/perform-send-action-task';
import SyncbackMetadataTask from '../tasks/syncback-metadata-task'
import DestroyDraftTask from '../tasks/destroy-draft-task';
import Thread from '../models/thread';
import Message from '../models/message';
import Utils from '../models/utils';
import Actions from '../actions';
import SoundRegistry from '../../registries/sound-registry';
import * as ExtensionRegistry from '../../registries/extension-registry';


const {DefaultSendActionKey} = SendActionsStore
/*
Public: DraftStore responds to Actions that interact with Drafts and exposes
public getter methods to return Draft objects and sessions.

It also creates and queues {Task} objects to persist changes to the Nylas
API.

Remember that a "Draft" is actually just a "Message" with `draft: true`.

Section: Drafts
*/
class DraftStore extends NylasStore {

  constructor() {
    super()
    this.listenTo(DatabaseStore, this._onDataChanged);
    this.listenTo(Actions.composeReply, this._onComposeReply);
    this.listenTo(Actions.composeForward, this._onComposeForward);
    this.listenTo(Actions.composePopoutDraft, this._onPopoutDraftClientId);
    this.listenTo(Actions.composeNewBlankDraft, this._onPopoutBlankDraft);
    this.listenTo(Actions.composeNewDraftToRecipient, this._onPopoutNewDraftToRecipient);
    this.listenTo(Actions.draftDeliveryFailed, this._onSendDraftFailed);
    this.listenTo(Actions.draftDeliverySucceeded, this._onSendDraftSuccess);
    this.listenTo(Actions.didCancelSendAction, this._onDidCancelSendAction);
    this.listenTo(Actions.sendQuickReply, this._onSendQuickReply);

    if (NylasEnv.isMainWindow()) {
      ipcRenderer.on('new-message', () => {
        Actions.composeNewBlankDraft();
      });
    }

    // Remember that these two actions only fire in the current window and
    // are picked up by the instance of the DraftStore in the current
    // window.
    this.listenTo(Actions.finalizeDraftAndSyncbackMetadata, this._onFinalizeDraftAndSyncbackMetadata);
    this.listenTo(Actions.sendDraft, this._onSendDraft);
    this.listenTo(Actions.destroyDraft, this._onDestroyDraft);
    this.listenTo(Actions.removeFile, this._onRemoveFile);

    NylasEnv.onBeforeUnload(this._onBeforeUnload);

    this._draftSessions = {};

    // We would ideally like to be able to calculate the sending state
    // declaratively from the existence of the SendDraftTask on the
    // TaskQueue.
    //
    // Unfortunately it takes a while for the Task to end up on the Queue.
    // Before it's there, the Draft session is fetched, changes are
    // applied, it's saved to the DB, and performLocal is run. In the
    // meantime, several triggers from the DraftStore may fire (like when
    // it's saved to the DB). At the time of those triggers, the task is
    // not yet on the Queue and the DraftStore incorrectly says
    // `isSendingDraft` is false.
    //
    // As a result, we keep track of the intermediate time between when we
    // request to queue something, and when it appears on the queue.
    this._draftsSending = {};

    ipcRenderer.on('mailto', this._onHandleMailtoLink);
    ipcRenderer.on('mailfiles', this._onHandleMailFiles);
  }

  /**
  Fetch a {DraftEditingSession} for displaying and/or editing the
  draft with `clientId`.

  @param {String} clientId - The clientId of the draft.
  @returns {Promise} - Resolves to an {DraftEditingSession} for the draft once it has been prepared
  */
  sessionForClientId(clientId) {
    if (!clientId) {
      throw new Error("DraftStore::sessionForClientId requires a clientId");
    }
    if (this._draftSessions[clientId] == null) {
      this._draftSessions[clientId] = this._createSession(clientId);
    }
    return this._draftSessions[clientId].prepare();
  }

  // Public: Look up the sending state of the given draftClientId.
  // In popout windows the existance of the window is the sending state.
  isSendingDraft(draftClientId) {
    return this._draftsSending[draftClientId] || false;
  }


  _doneWithSession(session) {
    session.teardown();
    delete this._draftSessions[session.draftClientId];
  }

  _cleanupAllSessions() {
    _.each(this._draftSessions, (session) => {
      this._doneWithSession(session)
    })
  }

  _onBeforeUnload = (readyToUnload) => {
    const promises = [];

    // Normally we'd just append all promises, even the ones already
    // fulfilled (nothing to save), but in this case we only want to
    // block window closing if we have to do real work. Calling
    // window.close() within on onbeforeunload could do weird things.
    _.each(this._draftSessions, (session) => {
      const draft = session.draft()
      if (draft && draft.pristine) {
        Actions.queueTask(new DestroyDraftTask(session.draftClientId));
      } else {
        promises.push(session.changes.commit());
      }
    })

    if (promises.length > 0) {
      // Important: There are some scenarios where all the promises resolve instantly.
      // Firing NylasEnv.close() does nothing if called within an existing beforeUnload
      // handler, so we need to always defer by one tick before re-firing close.
      // NOTE: this replaces Promise.settle:
      // http://bluebirdjs.com/docs/api/reflect.html
      Promise.all(promises.map(p => p.reflect())).then(() => {
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
  }

  _onDataChanged = (change) => {
    if (change.objectClass !== Message.name) { return; }
    const containsDraft = change.objects.some((msg) => msg.draft);
    if (!containsDraft) { return; }
    this.trigger(change);
  }

  _onSendQuickReply = ({thread, threadId, message, messageId}, body) => {
    return Promise.props(
      this._modelifyContext({thread, threadId, message, messageId})
    )
    .then(({message: m, thread: t}) => {
      return DraftFactory.createDraftForReply({message: m, thread: t, type: 'reply'});
    })
    .then((draft) => {
      draft.body = `${body}\n\n${draft.body}`
      draft.pristine = false;
      return DatabaseStore.inTransaction((t) => {
        return t.persistModel(draft);
      })
      .then(() => {
        Actions.sendDraft(draft.clientId);
      });
    });
  }

  _onComposeReply = ({thread, threadId, message, messageId, popout, type, behavior}) => {
    Actions.recordUserEvent("Draft Created", {type});
    return Promise.props(
      this._modelifyContext({thread, threadId, message, messageId})
    )
    .then(({message: m, thread: t}) => {
      if (['reply', 'reply-all'].includes(type)) {
        NylasEnv.timer.start(`compose-reply-${m.id}`)
      }
      return DraftFactory.createOrUpdateDraftForReply({message: m, thread: t, type, behavior});
    })
    .then(draft => {
      return this._finalizeAndPersistNewMessage(draft, {popout});
    });
  }

  _onComposeForward = ({thread, threadId, message, messageId, popout}) => {
    Actions.recordUserEvent("Draft Created", {type: "forward"});
    return Promise.props(
      this._modelifyContext({thread, threadId, message, messageId})
    )
    .then(({thread: t, message: m}) => {
      NylasEnv.timer.start(`compose-forward-${t.id}`)
      return DraftFactory.createDraftForForward({thread: t, message: m})
    })
    .then((draft) => {
      return this._finalizeAndPersistNewMessage(draft, {popout});
    });
  }

  _modelifyContext({thread, threadId, message, messageId}) {
    const queries = {};
    if (thread) {
      if (!(thread instanceof Thread)) {
        throw new Error("newMessageWithContext: `thread` present, expected a Model. Maybe you wanted to pass `threadId`?");
      }
      queries.thread = thread;
    } else {
      queries.thread = DatabaseStore.find(Thread, threadId);
    }

    if (message) {
      if (!(message instanceof Message)) {
        throw new Error("newMessageWithContext: `message` present, expected a Model. Maybe you wanted to pass `messageId`?");
      }
      queries.message = message;
    } else if (messageId != null) {
      queries.message = DatabaseStore
        .find(Message, messageId)
        .include(Message.attributes.body);
    } else {
      queries.message = DatabaseStore
        .findBy(Message, {threadId: threadId || thread.id})
        .order(Message.attributes.date.descending())
        .limit(1)
        .include(Message.attributes.body);
    }

    return queries;
  }

  _finalizeAndPersistNewMessage(draft, {popout} = {}) {
    // Give extensions an opportunity to perform additional setup to the draft
    ExtensionRegistry.Composer.extensions().forEach((extension) => {
      if (!extension.prepareNewDraft) { return; }
      extension.prepareNewDraft({draft});
    })

    // Optimistically create a draft session and hand it the draft so that it
    // doesn't need to do a query for it a second from now when the composer wants it.
    this._createSession(draft.clientId, draft);

    return DatabaseStore.inTransaction((t) => {
      return t.persistModel(draft);
    })
    .then(() => {
      if (popout) {
        this._onPopoutDraftClientId(draft.clientId);
      } else {
        Actions.focusDraft({draftClientId: draft.clientId});
      }
    })
    .thenReturn({draftClientId: draft.clientId, draft});
  }

  _createSession(clientId, draft) {
    this._draftSessions[clientId] = new DraftEditingSession(clientId, draft);
    return this._draftSessions[clientId]
  }

  _onPopoutNewDraftToRecipient = (contact) => {
    Actions.recordUserEvent("Draft Created", {type: "new"});
    const timerId = Utils.generateTempId()
    NylasEnv.timer.start(`open-composer-window-${timerId}`);
    return DraftFactory.createDraft({to: [contact]}).then((draft) => {
      return this._finalizeAndPersistNewMessage(draft).then(({draftClientId}) => {
        return this._onPopoutDraftClientId(draftClientId, {timerId, newDraft: true});
      });
    });
  }

  _onPopoutBlankDraft = () => {
    Actions.recordUserEvent("Draft Created", {type: "new"});
    const timerId = Utils.generateTempId()
    NylasEnv.timer.start(`open-composer-window-${timerId}`);
    return DraftFactory.createDraft().then((draft) => {
      return this._finalizeAndPersistNewMessage(draft).then(({draftClientId}) => {
        return this._onPopoutDraftClientId(draftClientId, {timerId, newDraft: true});
      });
    });
  }

  _onHandleMailtoLink = (event, urlString) => {
    Actions.recordUserEvent("Draft Created", {type: "mailto"});
    const timerId = Utils.generateTempId()
    NylasEnv.timer.start(`open-composer-window-${timerId}`);
    return DraftFactory.createDraftForMailto(urlString).then((draft) => {
      return this._finalizeAndPersistNewMessage(draft).then(({draftClientId}) => {
        return this._onPopoutDraftClientId(draftClientId, {timerId, newDraft: true});
      });
    }).catch((err) => {
      NylasEnv.showErrorDialog(err.toString())
    });
  }

  _onHandleMailFiles = (event, paths) => {
    Actions.recordUserEvent("Draft Created", {type: "dropped-file-in-dock"});
    const timerId = Utils.generateTempId()
    NylasEnv.timer.start(`open-composer-window-${timerId}`);
    return DraftFactory.createDraft().then((draft) => {
      return this._finalizeAndPersistNewMessage(draft);
    })
    .then(({draftClientId}) => {
      let remaining = paths.length;
      const callback = () => {
        remaining -= 1;
        if (remaining === 0) {
          this._onPopoutDraftClientId(draftClientId, {timerId});
        }
      };

      paths.forEach((path) => {
        Actions.addAttachment({
          filePath: path,
          messageClientId: draftClientId,
          onUploadCreated: callback,
        });
      })
    });
  }

  _onPopoutDraftClientId = (draftClientId, options = {}) => {
    if (draftClientId == null) {
      throw new Error("DraftStore::onPopoutDraftId - You must provide a draftClientId");
    }
    const {timerId} = options
    if (!timerId) {
      NylasEnv.timer.start(`open-composer-window-${draftClientId}`);
    }

    const title = options.newDraft ? "New Message" : "Message";
    return this.sessionForClientId(draftClientId).then((session) => {
      return session.changes.commit().then(() => {
        const draftJSON = session.draft().toJSON();
        // Since we pass a windowKey, if the popout composer draft already
        // exists we'll simply show that one instead of spawning a whole new
        // window.
        NylasEnv.newWindow({
          title,
          hidden: true, // We manually show in ComposerWithWindowProps::onDraftReady
          timerId: timerId || draftClientId,
          windowKey: `composer-${draftClientId}`,
          windowType: 'composer-preload',
          windowProps: _.extend(options, {draftClientId, draftJSON}),
        });
      });
    });
  }

  _onDestroyDraft = (draftClientId) => {
    const session = this._draftSessions[draftClientId];

    // Immediately reset any pending changes so no saves occur
    if (session) {
      this._doneWithSession(session);
    }

    // Stop any pending tasks related ot the draft
    TaskQueueStatusStore.queue().forEach((task) => {
      if (task instanceof BaseDraftTask && task.draftClientId === draftClientId) {
        Actions.dequeueTask(task.id);
      }
    })

    // Queue the task to destroy the draft
    Actions.queueTask(new DestroyDraftTask(draftClientId));

    if (NylasEnv.isComposerWindow()) {
      NylasEnv.close();
    }
  }

  _onFinalizeDraftAndSyncbackMetadata = async (draftClientId) => {
    const session = await this.sessionForClientId(draftClientId)
    const draft = await DraftHelpers.finalizeDraft(session)
    for (const {pluginId} of draft.pluginMetadata) {
      const task = new SyncbackMetadataTask(draft.clientId, Message.name, pluginId);
      Actions.queueTask(task);
    }
  }

  _onSendDraft = (draftClientId, sendActionKey = DefaultSendActionKey) => {
    this._draftsSending[draftClientId] = true;
    return this.sessionForClientId(draftClientId).then((session) => {
      return DraftHelpers.finalizeDraft(session)
      .then(() => {
        Actions.queueTask(new PerformSendActionTask(draftClientId, sendActionKey));
        this._doneWithSession(session);
        if (NylasEnv.config.get("core.sending.sounds")) {
          SoundRegistry.playSound('hit-send');
        }
        if (NylasEnv.isComposerWindow()) {
          NylasEnv.close();
        }
      });
    });
  }

  __testExtensionTransforms() {
    const clientId = NylasEnv.getWindowProps().draftClientId;
    return this.sessionForClientId(clientId).then((session) => {
      return this._prepareForSyncback(session).then(() => {
        window.__draft = session.draft();
        console.log("Done transforming draft. Available at window.__draft");
      });
    });
  }

  _onRemoveFile = ({file, messageClientId}) => {
    return this.sessionForClientId(messageClientId).then((session) => {
      let files = _.clone(session.draft().files) || [];
      files = _.reject(files, (f) => f.id === file.id);
      session.changes.add({files});
      return session.changes.commit();
    });
  }

  _onDidCancelSendAction = ({draftClientId}) => {
    delete this._draftsSending[draftClientId];
    this.trigger(draftClientId);
  }

  _onSendDraftSuccess = ({draftClientId}) => {
    delete this._draftsSending[draftClientId];
    this.trigger(draftClientId);
  }

  _onSendDraftFailed = ({draftClientId, threadId, errorMessage, errorDetail}) => {
    this._draftsSending[draftClientId] = false;
    this.trigger(draftClientId);
    if (NylasEnv.isMainWindow()) {
      // We delay so the view has time to update the restored draft. If we
      // don't delay the modal may come up in a state where the draft looks
      // like it hasn't been restored or has been lost.
      //
      // We also need to delay because the old draft window needs to fully
      // close. It takes windows currently (June 2016) 100ms to close by
      setTimeout(() => {
        this._notifyUserOfError({draftClientId, threadId, errorMessage, errorDetail});
      }, 300);
    }
  }

  _notifyUserOfError({draftClientId, threadId, errorMessage, errorDetail}) {
    const focusedThread = FocusedContentStore.focused('thread');
    if (threadId && focusedThread && focusedThread.id === threadId) {
      NylasEnv.showErrorDialog(errorMessage, {detail: errorDetail});
    } else {
      Actions.composePopoutDraft(draftClientId, {errorMessage, errorDetail});
    }
  }
}

export default new DraftStore();
