Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore'

###
Public: The Calendar model represents a Calendar object served by the
Nylas Platform API.  For more information about Calendar on the Nylas
Platform, read the [Calendar API
Documentation](https://nylas.com/docs/api#calendar)

## Attributes

`name`: {AttributeString} The name of the calendar.

`description`: {AttributeString} The description of the calendar.

This class also inherits attributes from {Model}

Section: Models
###
class Calendar extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      modelKey: 'name'
      jsonKey: 'name'

    'description': Attributes.String
      modelKey: 'description'
      jsonKey: 'description'

    'readOnly': Attributes.Boolean
      modelKey: 'readOnly'
      jsonKey: 'read_only'

module.exports = Calendar
