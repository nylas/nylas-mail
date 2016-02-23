Model = require './model'
Utils = require './utils'
Attributes = require '../attributes'
RegExpUtils = require '../../regexp-utils'
AccountStore = require '../stores/account-store'
FocusedPerspectiveStore = null # Circular Dependency
_ = require 'underscore'

name_prefixes = {}
name_suffixes = {}

###
Public: The Contact model represents a Contact object served by the Nylas Platform API.
For more information about Contacts on the Nylas Platform, read the
[Contacts API Documentation](https://nylas.com/docs/api#contacts)

## Attributes

`name`: {AttributeString} The name of the contact. Queryable.

`email`: {AttributeString} The email address of the contact. Queryable.

`thirdPartyData`: {AttributeObject} Extra data that we find out about a
contact.  The data is keyed by the 3rd party service that dumped the data
there. The value is an object of raw data in the form that the service
provides

We also have "normalized" optional data for each contact. This list may
grow as the needs of a contact become more complex.

This class also inherits attributes from {Model}

Section: Models
###
class Contact extends Model
  constructor: ->
    @thirdPartyData ?= {}
    super

  @attributes: _.extend {}, Model.attributes,
    'name': Attributes.String
      queryable: true
      modelKey: 'name'

    'email': Attributes.String
      queryable: true
      modelKey: 'email'

    # Contains the raw thirdPartyData (keyed by the vendor name) about
    # this contact.
    'thirdPartyData': Attributes.Object
      modelKey: 'thirdPartyData'

    # The following are "normalized" fields that we can use to consolidate
    # various thirdPartyData source. These list of attributes should
    # always be optional and may change as the needs of a Nylas contact
    # change over time.
    'title': Attributes.String(modelKey: 'title')
    'phone': Attributes.String(modelKey: 'phone')
    'company': Attributes.String(modelKey: 'company')


  @additionalSQLiteConfig:
    setup: ->
      ['CREATE INDEX IF NOT EXISTS ContactEmailIndex ON Contact(email)']

  @fromString: (string, {accountId} = {}) ->
    emailRegex = RegExpUtils.emailRegex()
    match = emailRegex.exec(string)
    if emailRegex.exec(string)
      throw new Error('Error while calling Contact.fromString: string contains more than one email')
    email = match[0]
    name = string[0...match.index - 1]
    name = name[0...-1] if name[name.length - 1] in ['<', '(']
    name = name.trim()
    return new Contact
      accountId: accountId
      name: name
      email: email

  # Public: Returns a string of the format `Full Name <email@address.com>` if
  # the contact has a populated name, just the email address otherwise.
  toString: ->
    # Note: This is used as the drag-drop text of a Contact token, in the
    # creation of message bylines "From Ben Gotow <ben@nylas>", and several other
    # places. Change with care.
    if @name and @name isnt @email then "#{@name} <#{@email}>" else @email

  toJSON: ->
    json = super
    json['name'] ||= json['email']
    json

  # Public: Returns true if the contact is the current user, false otherwise.
  # You should use this method instead of comparing the user's email address to
  # the account email, since it is case-insensitive and future-proof.
  isMe: ->
    account = AccountStore.accountForEmail(@email)
    return account?

  isMePhrase: ({includeAccountLabel} = {}) ->
    account = AccountStore.accountForEmail(@email)
    return null unless account

    if includeAccountLabel
      FocusedPerspectiveStore ?= require '../stores/focused-perspective-store'
      if account and FocusedPerspectiveStore.current().accountIds.length > 1
        return "You (#{account.label})"

    return "You"

  # Returns a {String} display name.
  # - "You" if the contact is the current user or an alias for the current user.
  # - `name` if the contact has a populated name
  # - `email` in all other cases.
  #
  # You can pass several options to customize the name:
  # - includeAccountLabel: If the contact represents the current user, include
  #   the account label afer "You"
  # - compact: If the contact has a name, make the name as short as possible
  #   (generally returns just the first name.)
  #
  displayName: ({includeAccountLabel, compact} = {}) ->
    compact ?= false
    includeAccountLabel ?= !compact

    if compact
      @isMePhrase({includeAccountLabel}) ? @firstName()
    else
      @isMePhrase({includeAccountLabel}) ? @_nameParts().join(' ')

  firstName: ->
    articles = ['a', 'the']
    for part in @_nameParts()
      if part.toLowerCase() not in articles
        return part
    return ""

  lastName: ->
    @_nameParts()[1..-1]?.join(" ") ? ""

  _nameParts: ->
    name = @name

    # At this point, if the name is empty we'll use the email address
    unless name && name.length
      name = (@email || "")

      # If the phrase has an '@', use everything before the @ sign
      # Unless there that would result in an empty string.
      name = name.split('@')[0] if name.indexOf('@') > 0

    # Take care of phrases like "Mike Kaylor via LinkedIn" that should be displayed
    # as the contents before the separator word. Do not break "Olivia"
    name = name.split(/(\svia\s)/i)[0]

    # Take care of whitespace
    name = name.trim()

    # Split the name into words and remove parts that are prefixes and suffixes
    parts = []
    parts = name.split(/\s+/)
    parts = _.reject parts, (part) ->
      part = part.toLowerCase().replace(/\./,'')
      (part of name_prefixes) or (part of name_suffixes)

    # If we've removed all the parts, just return the whole name
    parts = [name] if parts.join('').length == 0

    # If all that failed, fall back to email
    parts = [@email] if parts.join('').length == 0

    parts

module.exports = Contact

_.each ['2dlt','2lt','2nd lieutenant','adm','administrative','admiral','amb','ambassador','attorney','atty','baron','baroness','bishop','br','brig gen or bg','brigadier general','brnss','brother','capt','captain','chancellor','chaplain','chapln','chief petty officer','cmdr','cntss','coach','col','colonel','commander','corporal','count','countess','cpl','cpo','cpt','doctor','dr','dr and mrs','drs','duke','ens','ensign','estate of','father','father','fr','frau','friar','gen','general','gov','governor','hon','honorable','judge','justice','lieutenant','lieutenant colonel','lieutenant commander','lieutenant general','lieutenant junior grade','lord','lt','ltc','lt cmdr','lt col','lt gen','ltg','lt jg','m','madame','mademoiselle','maj','maj','master sergeant','master sgt','miss','miss','mlle','mme','monsieur','monsignor','monsignor','mr','mr','mr & dr','mr and dr','mr & mrs','mr and mrs','mrs & mr','mrs and mr','ms','ms','msgr','msgr','ofc','officer','president','princess','private','prof','prof & mrs','professor','pvt','rabbi','radm','rear admiral','rep','representative','rev','reverend','reverends','revs','right reverend','rtrev','s sgt','sargent','sec','secretary','sen','senator','senor','senora','senorita','sergeant','sgt','sgt','sheikh','sir','sister','sister','sr','sra','srta','staff sergeant','superintendent','supt','the hon','the honorable','the venerable','treas','treasurer','trust','trustees of','vadm','vice admiral'], (prefix) -> name_prefixes[prefix] = true

_.each ['1','2','3','4','5','6','7','i','ii','iii','iv','v','vi','vii','viii','ix','1st','2nd','3rd','4th','5th','6th','7th','cfx','cnd','cpa','csb','csc','csfn','csj','dc','dds','esq','esquire','first','fs','fsc','ihm','jd','jr','md','ocd','ofm','op','osa','osb','osf','phd','pm','rdc','ret','rsm','second','sj','sm','snd','sp','sr','ssj','us army','us army ret','usa','usa ret','usaf','usaf ret','usaf us air force','usmc us marine corp','usmcr us marine reserves','usn','usn ret','usn us navy','vm'], (suffix) -> name_suffixes[suffix] = true
