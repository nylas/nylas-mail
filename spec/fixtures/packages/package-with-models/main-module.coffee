Model = require '../../../../src/flux/models/model'
Task = require '../../../../src/task'

class ModelA extends Model
class ModelB extends Model
class TaskA extends Task

module.exports =
  modelConstructors: [ModelA, ModelB]
  taskConstructors: [TaskA]
  activate: ->
