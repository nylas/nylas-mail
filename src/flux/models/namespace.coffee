Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

class Namespace extends Model

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      modelKey: 'name'

    'provider': Attributes.String
      modelKey: 'provider'

    'emailAddress': Attributes.String
      queryable: true
      modelKey: 'emailAddress'
      jsonKey: 'email_address'

  me: ->
    Contact = require './contact'
    return new Contact
      namespaceId: @id
      name: @name
      email: @emailAddress

module.exports = Namespace
