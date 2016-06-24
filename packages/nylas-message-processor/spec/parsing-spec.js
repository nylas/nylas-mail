const path = require('path')
const fs = require('fs')
const {processMessage} = require('../processors/parsing')

const BASE_PATH = path.join(__dirname, 'fixtures')


it('parses the message correctly', (done) => {
  const bodyPath = path.join(BASE_PATH, '1-99174-body.txt')
  const headersPath = path.join(BASE_PATH, '1-99174-headers.txt')
  const rawBody = fs.readFileSync(bodyPath, 'utf8')
  const rawHeaders = fs.readFileSync(headersPath, 'utf8')
  const message = { rawHeaders, rawBody }
  const bodyPart = `<p>In <a href="https://github.com/electron/electron.atom.io/pull/352#discussion_r67715160">_data/apps.yml</a>:</p>`

  processMessage({message}).then((processed) => {
    expect(processed.headers['in-reply-to']).toEqual('<electron/electron.atom.io/pull/352@github.com>')
    expect(processed.messageId).toEqual('<electron/electron.atom.io/pull/352/r67715160@github.com>')
    expect(processed.subject).toEqual('Re: [electron/electron.atom.io] Add Jasper app (#352)')
    expect(processed.body.includes(bodyPart)).toBe(true)
    done()
  })
})
