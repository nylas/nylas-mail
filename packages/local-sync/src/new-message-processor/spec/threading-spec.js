/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
const path = require('path')
const {processMessage} = require('../processors/threading')

const BASE_PATH = path.join(__dirname, 'fixtures')

it('adds the message to the thread', (done) => {
  const {message, reply} = require(`${BASE_PATH}/thread`)
  const accountId = 'a-1'
  const mockDb = {
    Thread: {
      findAll: () => {
        return Promise.resolve([{
          id: 1,
          subject: "Loved your work and interests",
          messages: [message],
        }])
      },
      find: () => {
        return Promise.resolve(null)
      },
      create: (thread) => {
        thread.id = 1
        thread.addMessage = (newMessage) => {
          if (thread.messages) {
            thread.messages.push(newMessage.id)
          } else {
            thread.messages = [newMessage.id]
          }
        }
        return Promise.resolve(thread)
      },
    },
    Message: {
      findAll: () => {
        return Promise.resolve([message, reply])
      },
      find: () => {
        return Promise.resolve(reply)
      },
      create: () => {
        message.setThread = (thread) => {
          message.thread = thread.id
        };
        return Promise.resolve(message);
      },
    },
  }

  processMessage({db: mockDb, message: reply, accountId}).then((processed) => {
    expect(processed.thread).toBe(1)
    done()
  })
})
