Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore'

###
Public: The Namespace model represents a Namespace served by the Nylas Platform API.
Every object on the Nylas platform exists within a Namespace, which typically represents
an email account.

For more information about Namespaces on the Nylas Platform, read the
[Namespace API Documentation](https://nylas.com/docs/api#namespace)

## Attributes

`name`: {AttributeString} The name of the Namespace.

`provider`: {AttributeString} The Namespace's mail provider  (ie: `gmail`)

`emailAddress`: {AttributeString} The Namespace's email address
(ie: `ben@nylas.com`). Queryable.

`organizationUnit`: {AttributeString} Either "label" or "folder".
Depending on the provider, the account may be organized by folders or
labels.

This class also inherits attributes from {Model}

Section: Models
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

    'organizationUnit': Attributes.String
      modelKey: 'organizationUnit'
      jsonKey: 'organization_unit'

  # Returns a {Contact} model that represents the current user.
  me: ->
    Contact = require './contact'
    return new Contact
      namespaceId: @id
      name: @name
      email: @emailAddress

  # Public: The current organization_unit used by the namespace.
  usesLabels: -> @organizationUnit is "label"
  usesFolders: -> @organizationUnit is "folder"

  # Public: Returns the localized, properly capitalized provider name,
  # like Gmail, Exchange, or Outlook 365
  displayProvider: ->
    if @provider is 'eas'
      return 'Exchange'
    if @provider is 'gmail'
      return 'Gmail'
    return @provider

module.exports = Namespace
