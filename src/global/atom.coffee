{Point, Range} = require 'text-buffer'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{deprecate} = require 'grim'

module.exports =
  BufferedNodeProcess: require '../buffered-node-process'
  BufferedProcess: require '../buffered-process'
  Point: Point
  Range: Range
  Emitter: Emitter
  Disposable: Disposable
  CompositeDisposable: CompositeDisposable

# The following classes can't be used from a Task handler and should therefore
# only be exported when not running as a child node process
unless process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE
  module.exports.Task = require '../task'
