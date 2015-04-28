Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore-plus'

###
Public: The Namespace model represents a Namespace served by the Nylas Platform API.
Every object on the Nylas platform exists within a Namespace, which typically represents
an email account.

For more information about Namespaces on the Nylas Platform, read the
[https://nylas.com/docs/api#namespace](Namespace API Documentation)

## Attributes

`name`: {AttributeString} The name of the Namespace.

`provider`: {AttributeString} The Namespace's mail provider  (ie: `gmail`)

`emailAddress`: {AttributeString} The Namespace's email address
(ie: `ben@nylas.com`). Queryable.

This class also inherits attributes from {Model}

###
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

  # Returns a {Contact} model that represents the current user.
  me: ->
    Contact = require './contact'
    return new Contact
      namespaceId: @id
      name: @name
      email: @emailAddress

module.exports = Namespace
