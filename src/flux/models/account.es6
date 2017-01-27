/* eslint global-require:0 */
import Attributes from '../attributes'
import ModelWithMetadata from './model-with-metadata'

let CategoryStore = null
let Contact = null

/*
 * Public: The Account model represents a Account served by the Nylas Platform API.
 * Every object on the Nylas platform exists within a Account, which typically represents
 * an email account.
 *
 * For more information about Accounts on the Nylas Platform, read the
 * [Account API Documentation](https://nylas.com/cloud/docs#account)
 *
 * ## Attributes
 *
 * `name`: {AttributeString} The name of the Account.
 *
 * `provider`: {AttributeString} The Account's mail provider  (ie: `gmail`)
 *
 * `emailAddress`: {AttributeString} The Account's email address
 * (ie: `ben@nylas.com`). Queryable.
 *
 * `organizationUnit`: {AttributeString} Either "label" or "folder".
 * Depending on the provider, the account may be organized by folders or
 * labels.
 *
 * This class also inherits attributes from {Model}
 *
 * Section: Models
 */
export default class Account extends ModelWithMetadata {

  static SYNC_STATE_RUNNING = "running"

  static SYNC_STATE_AUTH_FAILED = "invalid"

  static SYNC_STATE_N1_CLOUD_AUTH_FAILED = "n1_cloud_auth_failed"

  static SYNC_STATE_ERROR = "sync_error"

  static attributes = Object.assign({}, ModelWithMetadata.attributes, {
    name: Attributes.String({
      modelKey: 'name',
    }),

    provider: Attributes.String({
      modelKey: 'provider',
    }),

    emailAddress: Attributes.String({
      queryable: true,
      modelKey: 'emailAddress',
      jsonKey: 'email_address',
    }),

    organizationUnit: Attributes.String({
      modelKey: 'organizationUnit',
      jsonKey: 'organization_unit',
    }),

    label: Attributes.String({
      modelKey: 'label',
    }),

    aliases: Attributes.Object({
      modelKey: 'aliases',
    }),

    defaultAlias: Attributes.Object({
      modelKey: 'defaultAlias',
      jsonKey: 'default_alias',
    }),

    syncState: Attributes.String({
      modelKey: 'syncState',
      jsonKey: 'sync_state',
    }),

    syncError: Attributes.Object({
      modelKey: 'syncError',
      jsonKey: 'sync_error',
    }),
  });

  constructor(args) {
    super(args)
    this.aliases = this.aliases || [];
    this.label = this.label || this.emailAddress;
    this.syncState = this.syncState || "running";
  }

  fromJSON(json) {
    super.fromJSON(json);
    if (!this.label) {
      this.label = this.emailAddress;
    }
    return this;
  }

  // Returns a {Contact} model that represents the current user.
  me() {
    Contact = Contact || require('./contact').default

    return new Contact({
      accountId: this.id,
      name: this.name,
      email: this.emailAddress,
    })
  }

  meUsingAlias(alias) {
    Contact = Contact || require('./contact').default

    if (!alias) {
      return this.me()
    }
    return Contact.fromString(alias, {accountId: this.id})
  }

  defaultMe() {
    if (this.defaultAlias) {
      return this.meUsingAlias(this.defaultAlias)
    }
    return this.me()
  }

  usesLabels() {
    return this.organizationUnit === "label"
  }

  usesFolders() {
    return this.organizationUnit === "folder"
  }

  categoryLabel() {
    if (this.usesFolders()) {
      return 'Folders'
    } else if (this.usesLabels()) {
      return 'Labels'
    }
    return 'Unknown'
  }

  categoryCollection() {
    return `${this.organizationUnit}s`
  }

  categoryIcon() {
    if (this.usesFolders()) {
      return 'folder.png'
    } else if (this.usesLabels()) {
      return 'tag.png'
    }
    return 'folder.png'
  }

  // Public: Returns the localized, properly capitalized provider name,
  // like Gmail, Exchange, or Outlook 365
  displayProvider() {
    if (this.provider === 'eas') {
      return 'Exchange'
    } else if (this.provider === 'gmail') {
      return 'Gmail'
    }
    return this.provider
  }

  canArchiveThreads() {
    CategoryStore = CategoryStore || require('../stores/category-store')

    return CategoryStore.getArchiveCategory(this)
  }

  canTrashThreads() {
    CategoryStore = CategoryStore || require('../stores/category-store')

    return CategoryStore.getTrashCategory(this)
  }

  defaultFinishedCategory() {
    CategoryStore = CategoryStore || require('../stores/category-store')

    const preferDelete = NylasEnv.config.get('core.reading.backspaceDelete')
    const archiveCategory = CategoryStore.getArchiveCategory(this)
    const trashCategory = CategoryStore.getTrashCategory(this)

    if (preferDelete || !archiveCategory) {
      return trashCategory
    }
    return archiveCategory
  }

  hasSyncStateError() {
    return this.syncState !== Account.SYNC_STATE_RUNNING
  }
}
