_ = require 'underscore'
Model = require './model'
Attributes = require '../attributes'

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

  hue: ->
    return 0 unless @displayName
    hue = 0
    for i in [0..(@displayName.length - 1)]
      hue += @displayName.charCodeAt(i)
    hue = hue * (396.0/512.0)
    hue

module.exports = Category
