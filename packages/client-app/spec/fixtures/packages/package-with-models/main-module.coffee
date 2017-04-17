Model = require '../../../../src/flux/models/model'
Task = require '../../../../src/task'
{TaskSubclassA} = require '../../../stores/task-subclass'

class ModelA extends Model
class ModelB extends Model

module.exports =
  modelConstructors: [ModelA, ModelB]
  taskConstructors: [TaskSubclassA]
  activate: ->
