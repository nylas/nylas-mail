_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

# We look for a few standard categories and display them in the Mailboxes
# portion of the left sidebar. Note that these may not all be present on
# a particular account.
StandardCategories = {
  "inbox",
  "important",
  "sent",
  "drafts",
  "all",
  "spam",
  "archive",
  "trash"
}

LockedCategories = {
  "sent"
}

HiddenCategories = {
  "sent"
  "drafts"
  "all"
  "archive"
  "starred"
  "important"
}

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

  @StandardCategoryNames: Object.keys(StandardCategories)
  @LockedCategoryNames: Object.keys(LockedCategories)
  @HiddenCategoryNames: Object.keys(HiddenCategories)

  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS CategoryNameIndex ON Category(account_id,name)',
       'CREATE UNIQUE INDEX IF NOT EXISTS CategoryClientIndex ON Category(client_id)']

  constructor: ->
    super

  fromJSON: (json) ->
    super
    @

  displayType: ->
    AccountStore = require '../stores/account-store'
    if AccountStore.accountForId(@category.accountId).usesLabels()
      return 'label'
    else
      return 'folder'

  hue: ->
    return 0 unless @displayName
    hue = 0
    for i in [0..(@displayName.length - 1)]
      hue += @displayName.charCodeAt(i)
    hue = hue * (396.0/512.0)
    hue

  isStandardCategory: (showImportant) ->
    showImportant ?= NylasEnv.config.get('core.workspace.showImportant')
    if showImportant is true
      StandardCategories[@name]?
    else
      StandardCategories[@name]? and @name isnt 'important'

  isLockedCategory: ->
    LockedCategories[@name]?

  isHiddenCategory: ->
    HiddenCategories[@name]?

  isUserCategory: ->
    not @isStandardCategory() and not @isHiddenCategory()

module.exports = Category
