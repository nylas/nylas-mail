import {
  Task,
  Actions,
  Message,
  TaskQueue,
  DraftStore,
  DatabaseStore,
  SendDraftTask,
  TaskQueueStatusStore,
} from 'nylas-exports'
import SendManyDraftsTask from '../lib/send-many-drafts-task'
import {PLUGIN_ID} from '../lib/mail-merge-constants'


xdescribe('SendManyDraftsTask', function describeBlock() {
  beforeEach(() => {
    this.baseDraft = new Message({
      clientId: 'baseId',
      files: ['f1', 'f2'],
      uploads: [],
    })
    this.d1 = new Message({
      clientId: 'd1',
      uploads: ['u1'],
    })
    this.d2 = new Message({
      clientId: 'd2',
    })

    this.task = new SendManyDraftsTask('baseId', ['d1', 'd2'])

    spyOn(DatabaseStore, 'modelify').andReturn(Promise.resolve([this.baseDraft, this.d1, this.d2]))
    spyOn(DatabaseStore, 'inTransaction').andCallFake((cb) => {
      return cb({persistModels() { return Promise.resolve() }})
    })
  });

  describe('performRemote', () => {
    beforeEach(() => {
      spyOn(this.task, 'prepareDraftsToSend').andCallFake((baseId, draftIds) => {
        return Promise.resolve(draftIds.map(id => this[id]))
      })
      spyOn(this.task, 'queueSendTasks').andReturn(Promise.resolve())
      spyOn(this.task, 'waitForSendTasks').andReturn(Promise.resolve())
      spyOn(this.task, 'onTasksProcessed')
      spyOn(this.task, 'handleError').andCallFake((error) =>
        Promise.resolve([Task.Status.Failed, error])
      )
    });

    it('queues all drafts for sending when no tasks have been queued yet', () => {
      waitsForPromise(() => {
        return this.task.performRemote()
        .then(() => {
          expect(this.task.prepareDraftsToSend).toHaveBeenCalledWith('baseId', ['d1', 'd2'])
          expect(this.task.queueSendTasks).toHaveBeenCalledWith([this.d1, this.d2])
          expect(this.task.waitForSendTasks).toHaveBeenCalled()
        })
      })
    });

    it('only queues drafts that have not been queued for sending', () => {
      this.task.queuedDraftIds = new Set(['d1'])
      waitsForPromise(() => {
        return this.task.performRemote()
        .then(() => {
          expect(this.task.prepareDraftsToSend).toHaveBeenCalledWith('baseId', ['d2'])
          expect(this.task.queueSendTasks).toHaveBeenCalledWith([this.d2])
          expect(this.task.waitForSendTasks).toHaveBeenCalled()
        })
      })
    });

    it('only waits for tasks to complete when all drafts have been queued for sending', () => {
      this.task.queuedDraftIds = new Set(['d1', 'd2'])
      waitsForPromise(() => {
        return this.task.performRemote()
        .then(() => {
          expect(this.task.prepareDraftsToSend).not.toHaveBeenCalled()
          expect(this.task.queueSendTasks).not.toHaveBeenCalled()
          expect(this.task.waitForSendTasks).toHaveBeenCalled()
        })
      })
    });

    it('handles errors', () => {
      jasmine.unspy(this.task, 'onTasksProcessed')
      spyOn(this.task, 'onTasksProcessed').andReturn(Promise.reject(new Error('Oh no!')))
      this.task.queuedDraftIds = new Set(['d1', 'd2'])
      waitsForPromise(() => {
        return this.task.performRemote()
        .then(() => {
          expect(this.task.handleError).toHaveBeenCalled()
        })
      })
    });
  });

  describe('prepareDraftsToSend', () => {
    it('updates the files and uploads on each draft to send', () => {
      waitsForPromise(() => {
        return this.task.prepareDraftsToSend('baseId', ['d1', 'd2'])
        .then((draftsToSend) => {
          expect(DatabaseStore.modelify).toHaveBeenCalledWith(Message, ['baseId', 'd1', 'd2'])
          expect(draftsToSend.length).toBe(2)
          expect(draftsToSend[0].files).toEqual(this.baseDraft.files)
          expect(draftsToSend[0].uploads).toEqual([])
          expect(draftsToSend[1].files).toEqual(this.baseDraft.files)
          expect(draftsToSend[1].uploads).toEqual([])
        })
      })
    });
  });

  describe('queueSendTasks', () => {
    beforeEach(() => {
      spyOn(Actions, 'queueTask')
    });

    it('queues SendDraftTask for all passed in drafts', () => {
      waitsForPromise(() => {
        const promise = this.task.queueSendTasks([this.d1, this.d2], 0)
        advanceClock(1)
        advanceClock(1)
        return promise.then(() => {
          expect(Actions.queueTask.calls.length).toBe(2)
          expect(Array.from(this.task.queuedDraftIds)).toEqual(['d1', 'd2'])
          Actions.queueTask.calls.forEach(({args}, idx) => {
            const task = args[0]
            expect(task instanceof SendDraftTask).toBe(true)
            expect(task.draftClientId).toEqual(`d${idx + 1}`)
          })
        })
      })
    });
  });

  describe('waitForSendTasks', () => {
    it('it updates queuedDraftIds and warns if there are no tasks matching the draft client id', () => {
      this.task.queuedDraftIds = new Set(['d2'])
      spyOn(TaskQueue, 'allTasks').andReturn([])
      spyOn(console, 'warn')
      waitsForPromise(() => {
        return this.task.waitForSendTasks()
        .then(() => {
          expect(this.task.queuedDraftIds.size).toBe(0)
          expect(console.warn).toHaveBeenCalled()
        })
      })
    });

    it('resolves when all queued tasks complete', () => {
      this.task.queuedDraftIds = new Set(['d2'])
      spyOn(TaskQueue, 'allTasks').andReturn([new SendDraftTask('d2')])
      spyOn(TaskQueueStatusStore, 'waitForPerformRemote').andCallFake((task) => {
        task.queueState.status = Task.Status.Success
        return Promise.resolve(task)
      })

      waitsForPromise(() => {
        return this.task.waitForSendTasks()
        .then(() => {
          expect(Array.from(this.task.queuedDraftIds)).toEqual([])
          expect(this.task.failedDraftIds).toEqual([])
        })
      })
    });

    it('saves any draft ids of drafts that failed to send', () => {
      this.task.queuedDraftIds = new Set(['d1', 'd2'])
      spyOn(TaskQueue, 'allTasks').andReturn([new SendDraftTask('d1'), new SendDraftTask('d2')])
      spyOn(TaskQueueStatusStore, 'waitForPerformRemote').andCallFake((task) => {
        if (task.draftClientId === 'd1') {
          task.queueState.status = Task.Status.Failed
        } else {
          task.queueState.status = Task.Status.Success
        }
        return Promise.resolve(task)
      })

      waitsForPromise(() => {
        return this.task.waitForSendTasks()
        .then(() => {
          expect(Array.from(this.task.queuedDraftIds)).toEqual([])
          expect(this.task.failedDraftIds).toEqual(['d1'])
        })
      })
    });
  });

  describe('handleError', () => {
    beforeEach(() => {
      this.baseDraft.applyPluginMetadata(PLUGIN_ID, {tableDataSource: {}})
      this.d1.applyPluginMetadata(PLUGIN_ID, {rowIdx: 0})
      this.d2.applyPluginMetadata(PLUGIN_ID, {rowIdx: 1})
      this.baseSession = {
        draft: () => { return this.baseDraft },
        changes: {
          addPluginMetadata: jasmine.createSpy('addPluginMetadata'),
          commit() { return Promise.resolve() },
        },
      }

      this.task.failedDraftIds = ['d1', 'd2']
      spyOn(Actions, 'destroyDraft')
      spyOn(Actions, 'composePopoutDraft')
      spyOn(DraftStore, 'sessionForClientId').andReturn(Promise.resolve(this.baseSession))

      jasmine.unspy(DatabaseStore, 'modelify')
      spyOn(DatabaseStore, 'modelify').andReturn(Promise.resolve([this.d1, this.d2]))
    });

    it('correctly saves the failed rowIdxs to the base draft metadata', () => {
      waitsForPromise(() => {
        return this.task.handleError({message: 'Error!'})
        .then((status) => {
          expect(status[0]).toBe(Task.Status.Failed)
          expect(DatabaseStore.modelify).toHaveBeenCalledWith(Message, this.task.failedDraftIds)
          expect(this.baseSession.changes.addPluginMetadata).toHaveBeenCalledWith(PLUGIN_ID, {
            tableDataSource: {},
            failedDraftRowIdxs: [0, 1],
          })
        })
      })
    });

    it('correctly destroys failed drafts', () => {
      waitsForPromise(() => {
        return this.task.handleError({message: 'Error!'})
        .then((status) => {
          expect(status[0]).toBe(Task.Status.Failed)
          expect(Actions.destroyDraft.calls.length).toBe(2)
          expect(Actions.destroyDraft.calls[0].args).toEqual(['d1'])
          expect(Actions.destroyDraft.calls[1].args).toEqual(['d2'])
        })
      })
    });

    it('correctly pops out base composer with error msg', () => {
      waitsForPromise(() => {
        return this.task.handleError({message: 'Error!'})
        .then((status) => {
          expect(status[0]).toBe(Task.Status.Failed)
          expect(Actions.composePopoutDraft).toHaveBeenCalledWith('baseId', {
            errorMessage: 'Error!',
          })
        })
      })
    });
  });
});
