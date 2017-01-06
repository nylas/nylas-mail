const MessageProcessor = require('../message-processor')


class SyncOperation {
  async run(...args) {
    if (MessageProcessor.queueIsFull()) {
      console.log(`🔃  Skipping sync operation - Message processing queue is full`)
      return Promise.resolve()
    }

    return this.runOperation(...args)
  }

  async runOperation() {
    throw new Error('Must implement `SyncOperation::runOperation`')
  }
}

module.exports = SyncOperation
