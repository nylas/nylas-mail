const path = require('path')
const fs = require('fs')
const assert = require('assert')
const {processMessage} = require('../processors/parsing')

const BASE_PATH = path.join('/', 'Users', 'juan', 'Downloads', 'sample data')

const tests = []

function it(name, testFn) {
  tests.push(testFn)
}

function test() {
  tests.reduce((prev, t) => prev.then(() => t()), Promise.resolve())
  .then(() => console.log('Success!'))
  .catch((err) => console.log(err))
}

it('parses the message correctly', () => {
  const bodyPath = path.join(BASE_PATH, '1-99174-body.txt')
  const headersPath = path.join(BASE_PATH, '1-99174-headers.txt')
  const rawBody = fs.readFileSync(bodyPath, 'utf8')
  const rawHeaders = fs.readFileSync(headersPath, 'utf8')
  const message = { rawHeaders, rawBody }
  return processMessage({message}).then((processed) => {
    const bodyPart = `<p>In <a href="https://github.com/electron/electron.atom.io/pull/352#discussion_r67715160">_data/apps.yml</a>:</p>`
    assert.equal(processed.headers['in-reply-to'], '<electron/electron.atom.io/pull/352@github.com>')
    assert.equal(processed.messageId, '<electron/electron.atom.io/pull/352/r67715160@github.com>')
    assert.equal(processed.subject, 'Re: [electron/electron.atom.io] Add Jasper app (#352)')
    assert.equal(processed.body.includes(bodyPart), true)
  })
})

test()
