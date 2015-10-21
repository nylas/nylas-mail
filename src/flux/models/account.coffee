Model = require './model'
Attributes = require '../attributes'
_ = require 'underscore'

###
Public: The Account model represents a Account served by the Nylas Platform API.
Every object on the Nylas platform exists within a Account, which typically represents
an email account.

For more information about Accounts on the Nylas Platform, read the
[Account API Documentation](https://nylas.com/docs/api#Account)

## Attributes

`name`: {AttributeString} The name of the Account.

`provider`: {AttributeString} The Account's mail provider  (ie: `gmail`)

`emailAddress`: {AttributeString} The Account's email address
(ie: `ben@nylas.com`). Queryable.

`organizationUnit`: {AttributeString} Either "label" or "folder".
Depending on the provider, the account may be organized by folders or
labels.

This class also inherits attributes from {Model}

Section: Models
###
class Account extends Model

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
      accountId: @id
      name: @name
      email: @emailAddress

  # Public: The current organization_unit used by the account.
  usesLabels: -> @organizationUnit is "label"
  usesFolders: -> @organizationUnit is "folder"

  categoryClass: ->
    if @usesLabels()
      return require './label'
    else
      return require './folder'

  # Public: Returns the localized, properly capitalized provider name,
  # like Gmail, Exchange, or Outlook 365
  displayProvider: ->
    if @provider is 'eas'
      return 'Exchange'
    if @provider is 'gmail'
      return 'Gmail'
    return @provider

  usesImportantFlag: ->
    @provider is 'gmail'

module.exports = Account
