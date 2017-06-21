import {NylasAPIRequest, Message, SyncbackMetadataTask, Thread} from 'nylas-exports'

describe("SyncbackMetadataTask", () => {
  it("sends messageIds if the object is a Thread", () => {
    spyOn(NylasAPIRequest.prototype, 'run').andCallFake(function fakeRun() {
      return Promise.resolve(this)
    })
    const thread = new Thread({id: 't:5'})
    thread.applyPluginMetadata('test-plugin', {key: 'value'})
    const messages = [
      new Message({threadId: thread.id}),
      new Message({threadId: thread.id}),
    ]
    thread.messages = () => messages
    const task = new SyncbackMetadataTask(thread.id, 'Thread', 'test-plugin')
    waitsForPromise(() => task.makeRequest(thread).then(nylasAPIRequest => {
      expect(nylasAPIRequest.options.body.messageIds).toEqual(messages.map(m => m.id))
    }))
  })

  it("does not send messageIds if the object is not a Thread", () => {
    spyOn(NylasAPIRequest.prototype, 'run').andCallFake(function fakeRun() {
      return Promise.resolve(this)
    })
    const message = new Message({id: '5'})
    message.applyPluginMetadata('test-plugin', {key: 'value'})
    const task = new SyncbackMetadataTask(message.id, 'Message', 'test-plugin')
    waitsForPromise(() => task.makeRequest(message).then(nylasAPIRequest => {
      expect(nylasAPIRequest.options.body.messageIds).toBeUndefined()
    }))
  })
})
