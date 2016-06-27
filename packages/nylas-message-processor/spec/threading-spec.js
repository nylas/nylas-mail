const path = require('path')
const fs = require('fs')
const {DatabaseConnector} = require('nylas-core')
const {processMessage} = require('../processors/threading')

const BASE_PATH = path.join(__dirname, 'fixtures')


it('adds the message to the thread', (done) => {
  const {message, reply} = require(`${BASE_PATH}/thread`)
  const accountId = 'a-1'
  const mockDb = {
    Thread: {
      findAll: () => {
        return Promise.resolve([
        {
          id: 1,
          cleanedSubject: "Loved your work and interests",
          messages: [message],
        }])
      },
      find: () => {
        return Promise.resolve(null)
      },
      create: (thread) => {
        thread.id = 1
        thread.addMessage = (message) => {
          if (thread.messages) {
            thread.messages.push(message.id)
          } else {
            thread.messages = [message.id]
          }
        }
        return Promise.resolve(thread)
      }
    },
    Message: {
      findAll: () => {
        return Promise.resolve([message, reply])
      },
      find: () => {
        return Promise.resolve(reply)
      },
      create: (message) => {
        message.setThread = (thread) => {
          console.log("setting")
          message.thread = thread.id
        }
        return Promise.resolve(message)
      }
    }
  }

  processMessage({db: mockDb, message: reply, accountId}).then((processed) => {
    expect(processed.thread).toBe(1)
    done()
  })
})
