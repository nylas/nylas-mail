{Listener, Publisher} = require '../flux/modules/reflux-coffee'
CoffeeHelpers = require '../flux/coffee-helpers'

# A simple Flux implementation
class MailspringStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

module.exports = MailspringStore
