_ = require 'underscore-plus'

module.exports =
  # This copied out CoffeeScript
  includeModule: (mixin) ->
    if not mixin
      return throw 'Supplied mixin was not found'

    if not _
      return throw 'Underscore was not found'

    mixin = mixin.prototype if _.isFunction(mixin)

    # Make a copy of the superclass with the same constructor and use it
    # instead of adding functions directly to the superclass.
    if @.__super__
      tmpSuper = _.extend({}, @.__super__)
      tmpSuper.constructor = @.__super__.constructor

    @.__super__ = tmpSuper || {}

    # Copy function over to prototype and the new intermediate superclass.
    for methodName, funct of mixin when methodName not in ['included']
      @.__super__[methodName] = funct

      if not @prototype.hasOwnProperty(methodName)
        @prototype[methodName] = funct

    mixin.included?.apply(this)
    this

  # Allows the root objects to extend other objects as class methods via the
  # object.
  extendModule: (module) ->
    if not module?
      console.warn "The module you are trying to extend does not exist. Ensure you have put it on this page's manifest."

    if _.isFunction(module) then module = module()

    @[key] = value for key, value of module
    return @

  # Allows the root objects to include other objects as instance methods via
  # the prototype
  simpleInclude: (module) ->
    if not module?
      console.warn "The module you are trying to include does not exist. Ensure you have put it on this page's manifest."

    if _.isFunction(module) then module = module()

    @::[key] = value for key, value of module
    return @

  # This should be called as the first item from the constructor of an
  # object.
  #
  # You can optionally pass a refernce to a super's prototype.
  boundInclude: (module, _super) ->
    if not module?
      console.warn "The module you are trying to include does not exist. Ensure you have put it on this page's manifest."
      return

    if not _.isFunction(module)
      console.warn "To do a scoped include the Module must be a function instead of a plain old javascript object thereby allowing `this` to be bound properly."
      return

    for key, value of module.call(@, _super)
      @[key] = value unless @[key]?
    return @
