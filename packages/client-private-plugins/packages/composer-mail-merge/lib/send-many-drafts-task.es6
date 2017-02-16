import {
  Task,
  Actions,
  Message,
  TaskQueue,
  DraftStore,
  BaseDraftTask,
  SendDraftTask,
  SoundRegistry,
  DatabaseStore,
  TaskQueueStatusStore,
} from 'nylas-exports'
import {PLUGIN_ID} from './mail-merge-constants'


const SEND_DRAFT_THROTTLE = 500

export default class SendManyDraftsTask extends Task {

  constructor(baseDraftClientId, draftIdsToSend = []) {
    super()
    this.baseDraftClientId = baseDraftClientId
    this.draftIdsToSend = draftIdsToSend

    this.queuedDraftIds = new Set()
    this.failedDraftIds = []
  }

  label() {
    return `Sending ${this.draftIdsToSend.length} messages`
  }

  shouldDequeueOtherTask(other) {
    return other instanceof SendManyDraftsTask && other.draftClientId === this.baseDraftClientId;
  }

  isDependentOnTask(other) {
    const isSameDraft = other.draftClientId === this.baseDraftClientId;
    const isSaveOrSend = other instanceof BaseDraftTask;
    return isSameDraft && isSaveOrSend
  }

  performLocal() {
    if (!this.baseDraftClientId) {
      const errMsg = `Attempt to call SendManyDraftsTask.performLocal without a baseDraftClientId`;
      return Promise.reject(new Error(errMsg));
    }
    if (this.draftIdsToSend.length === 0) {
      const errMsg = `Attempt to call SendManyDraftsTask.performLocal without draftIdsToSend`;
      return Promise.reject(new Error(errMsg));
    }

    return Promise.resolve();
  }

  performRemote() {
    const unqueuedDraftIds = this.draftIdsToSend.filter(id => !this.queuedDraftIds.has(id))

    if (unqueuedDraftIds.length > 0) {
      return (
        DatabaseStore.modelify(Message, unqueuedDraftIds)
        .then((draftsToSend) => this.queueSendTasks(draftsToSend))
        .then(() => this.waitForSendTasks())
        .then(() => this.onTasksProcessed())
        .catch((error) => this.handleError(error))
      )
    }
    return (
      this.waitForSendTasks()
      .then(() => this.onTasksProcessed())
      .catch((error) => this.handleError(error))
    )
  }

  queueSendTasks(draftsToSend, throttle = SEND_DRAFT_THROTTLE) {
    return Promise.each(draftsToSend, (draft) => {
      return new Promise((resolve) => {
        const task = new SendDraftTask(draft.clientId, {
          playSound: false,
          emitError: false,
          allowMultiSend: false,
        })
        Actions.queueTask(task)
        this.queuedDraftIds.add(draft.clientId)
        setTimeout(resolve, throttle)
      })
    })
  }

  waitForSendTasks() {
    const waitForTaskPromises = Array.from(this.queuedDraftIds).map((draftClientId) => {
      const tasks = TaskQueue.allTasks()
      const task = tasks.find((t) => t instanceof SendDraftTask && t.draftClientId === draftClientId)
      if (!task) {
        console.warn(`SendManyDraftsTask: Can't find queued SendDraftTask for draft id: ${draftClientId}`)
        this.queuedDraftIds.delete(draftClientId)
        return Promise.resolve()
      }

      return TaskQueueStatusStore.waitForPerformRemote(task)
      .then((completedTask) => {
        if (!this.queuedDraftIds.has(completedTask.draftClientId)) { return }

        const {status} = completedTask.queueState
        if (status === Task.Status.Failed) {
          this.failedDraftIds.push(completedTask.draftClientId)
        }

        this.queuedDraftIds.delete(completedTask.draftClientId)
      })
    })
    return Promise.all(waitForTaskPromises)
  }

  onTasksProcessed() {
    if (this.failedDraftIds.length > 0) {
      const error = new Error(
        `Sorry, some of your messages failed to send.
This could be due to sending limits imposed by your mail provider.
Please try again after a while. Also make sure your messages are addressed correctly and are not too large.`,
      )
      return this.handleError(error)
    }

    Actions.recordUserEvent("Mail Merge Sent", {
      numItems: this.draftIdsToSend.length,
      numFailedItems: this.failedDraftIds.length,
    })

    if (NylasEnv.config.get("core.sending.sounds")) {
      SoundRegistry.playSound('send');
    }
    return Promise.resolve(Task.Status.Success)
  }

  handleError(error) {
    return (
      DraftStore.sessionForClientId(this.baseDraftClientId)
      .then((session) => {
        return DatabaseStore.modelify(Message, this.failedDraftIds)
        .then((failedDrafts) => {
          const failedDraftRowIdxs = failedDrafts.map((draft) => draft.metadataForPluginId(PLUGIN_ID).rowIdx)
          const currentMetadata = session.draft().metadataForPluginId(PLUGIN_ID)
          const nextMetadata = {
            ...currentMetadata,
            failedDraftRowIdxs,
          }
          session.changes.addPluginMetadata(PLUGIN_ID, nextMetadata)
          return session.changes.commit()
        })
      })
      .then(() => {
        this.failedDraftIds.forEach((id) => Actions.destroyDraft(id))
        Actions.composePopoutDraft(this.baseDraftClientId, {errorMessage: error.message})
        return Promise.resolve([Task.Status.Failed, error])
      })
    )
  }

  toJSON() {
    const json = {...super.toJSON()}
    json.queuedDraftIds = Array.from(json.queuedDraftIds)
    return json
  }

  fromJSON(json) {
    const result = super.fromJSON(json)
    result.queuedDraftIds = new Set(result.queuedDraftIds)
    return result
  }
}
