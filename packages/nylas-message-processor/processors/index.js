const fs = require('fs')

const processors = fs.readdirSync(__dirname)
.filter((file) => file !== 'index.js')
.map((file) => {
  const {processMessage, order} = require(`./${file}`)
  return {
    order,
    processMessage: processMessage || ((msg) => msg),
  }
})
.sort(({order: o1}, {order: o2}) => o1 - o2)
.map(({processMessage}) => processMessage)

module.exports = {processors}
