const fs = require('fs')

const processors = fs.readdirSync(__dirname)
.filter((file) => file !== 'index.js')
.map((file) => {
  return require(`./${file}`).processMessage
})

module.exports = {processors}
