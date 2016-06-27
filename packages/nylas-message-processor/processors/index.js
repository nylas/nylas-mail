const fs = require('fs')

const processors = fs.readdirSync(__dirname)
.filter((file) => file !== 'index.js')
.map((file) => {
  const {processMessage, order} = require(`./${file}`)
  if (!processMessage) {
    throw new Error(`${file} does not export a method named processMessage.`)
  }
  return {processMessage, order}
})
.sort((p1, p2) => p1.order - p2.order)
.map((p) => p.processMessage)

module.exports = {processors}
