Utils = require './utils'
ModelQuery = require './query'

class JSONBlobQuery extends ModelQuery
  formatResultObjects: (objects) =>
    return objects[0]?.json || null

module.exports = JSONBlobQuery
