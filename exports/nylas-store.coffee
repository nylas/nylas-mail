{Listener, Publisher} = require '../src/flux/modules/reflux-coffee'
CoffeeHelpers = require '../src/flux/coffee-helpers'

# A simple Flux implementation
class NylasStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

module.exports = NylasStore
