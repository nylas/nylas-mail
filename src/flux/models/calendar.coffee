Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

###
Public: The Calendar model represents a Calendar object served by the Nylas Platform API.
For more information about Calendar on the Nylas Platform, read the
[https://nylas.com/docs/api#calendar](Calendar API Documentation)

## Attributes

`name`: {AttributeString} The name of the calendar.

`description`: {AttributeString} The description of the calendar.

This class also inherits attributes from {Model}

###
class Calendar extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      modelKey: 'name'
    'description': Attributes.String
      modelKey: 'description'
    
module.exports = Calendar