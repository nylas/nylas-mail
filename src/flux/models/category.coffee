_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

# We look for a few standard categories and display them in the Mailboxes
# portion of the left sidebar. Note that these may not all be present on
# a particular account.
StandardCategoryNames = [
  "inbox"
  "important"
  "sent"
  "drafts"
  "all"
  "spam"
  "archive"
  "trash"
]

LockedCategoryNames = [
  "sent"
]

HiddenCategoryNames = [
  "sent"
  "drafts"
  "all"
  "archive"
  "starred"
  "important"
]

AllMailName = "all"

###
Private:
This abstract class has only two concrete implementations:
  - `Folder`
  - `Label`

See the equivalent models for details.

Folders and Labels have different semantics. The `Category` class only exists to help DRY code where they happen to behave the same

## Attributes

`name`: {AttributeString} The internal name of the label or folder. Queryable.

`displayName`: {AttributeString} The display-friendly name of the label or folder. Queryable.

Section: Models
###
class Category extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      queryable: true
      modelKey: 'name'

    'displayName': Attributes.String
      queryable: true
      modelKey: 'displayName'
      jsonKey: 'display_name'

    'isDeleted': Attributes.Boolean
      modelKey: 'isDeleted'
      jsonKey: 'is_deleted'

  @Types:
    Standard: 'standard'
    Locked: 'locked'
    User: 'user'
    Hidden: 'hidden'

  @StandardCategoryNames: StandardCategoryNames
  @LockedCategoryNames: LockedCategoryNames
  @HiddenCategoryNames: HiddenCategoryNames

  constructor: ->
    super
    @_initCategoryTypes()

  fromJSON: (json) ->
    super
    @_initCategoryTypes()
    @

  _initCategoryTypes: =>
    @types = []
    if not (@name in StandardCategoryNames) and not (@name in HiddenCategoryNames)
      @types.push @constructor.Types.User
    if @name in LockedCategoryNames
      @types.push @constructor.Types.Hidden
    if @name in StandardCategoryNames
      @types.push @constructor.Types.Standard
    if @name in HiddenCategoryNames
      @types.push @constructor.Types.Hidden

    # Define getter for isStandardCategory. Must take into account important
    # setting
    Object.defineProperty @, "isStandardCategory",
      enumerable: true
      configurable: true
      value: (showImportant)=>
        showImportant ?= NylasEnv.config.get('core.workspace.showImportant')
        val = @constructor.Types.Standard
        if showImportant is true
          val in @types
        else
          val in @types and @name isnt 'important'

    # Define getters for other category types
    for key, val of @constructor.Types
      continue if val is @constructor.Types.Standard
      do (key, val) =>
        Object.defineProperty @, "is#{key}Category",
          enumerable: true
          configurable: true
          value: => val in @types

  hue: ->
    return 0 unless @displayName
    hue = 0
    for i in [0..(@displayName.length - 1)]
      hue += @displayName.charCodeAt(i)
    hue = hue * (396.0/512.0)
    hue

module.exports = Category
