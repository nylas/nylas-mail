Utils = require '../src/flux/models/utils'

{APIError,
 OfflineError,
 TimeoutError} = require '../src/flux/errors'

Exports =

  React: require 'react'
  BufferedProcess: require '../src/buffered-process'
  BufferedNodeProcess: require '../src/buffered-node-process'

  # The Task Queue
  Task: require '../src/flux/tasks/task'
  TaskQueue: require '../src/flux/stores/task-queue'
  UndoRedoStore: require '../src/flux/stores/undo-redo-store'

  # Tasks
  ChangeLabelsTask: require '../src/flux/tasks/change-labels-task'
  ChangeFolderTask: require '../src/flux/tasks/change-folder-task'
  UpdateThreadsTask: require '../src/flux/tasks/update-threads-task'
  CreateMetadataTask: require '../src/flux/tasks/create-metadata-task'
  ArchiveThreadHelper: require '../src/flux/tasks/archive-thread-helper'
  DestroyMetadataTask: require '../src/flux/tasks/destroy-metadata-task'

  # The Database
  DatabaseStore: require '../src/flux/stores/database-store'
  ModelView: require '../src/flux/stores/model-view'
  DatabaseView: require '../src/flux/stores/database-view'
  SearchView: require '../src/flux/stores/search-view'

  # Actions
  Actions: require '../src/flux/actions'

  # API Endpoints
  NylasAPI: require '../src/flux/nylas-api'
  EdgehillAPI: require '../src/flux/edgehill-api'

  # Testing
  NylasTestUtils: require '../spec-nylas/test_utils'

  # Component Registry
  ComponentRegistry: require '../src/component-registry'

  # Utils
  Utils: Utils
  DOMUtils: require '../src/dom-utils'
  CanvasUtils: require '../src/canvas-utils'
  RegExpUtils: require '../src/regexp-utils'
  MessageUtils: require '../src/flux/models/message-utils'

  # Mixins
  UndoManager: require '../src/flux/undo-manager'

  PriorityUICoordinator: require '../src/priority-ui-coordinator'

  # Stores
  CategoryStore: require '../src/flux/stores/category-store'
  DraftStore: require '../src/flux/stores/draft-store'
  DraftCountStore: require '../src/flux/stores/draft-count-store'
  DraftStoreExtension: require '../src/flux/stores/draft-store-extension'
  MessageStore: require '../src/flux/stores/message-store'
  MessageStoreExtension: require '../src/flux/stores/message-store-extension'
  ContactStore: require '../src/flux/stores/contact-store'
  MetadataStore: require '../src/flux/stores/metadata-store'
  NamespaceStore: require '../src/flux/stores/namespace-store'
  AnalyticsStore: require '../src/flux/stores/analytics-store'
  WorkspaceStore: require '../src/flux/stores/workspace-store'
  FocusedCategoryStore: require '../src/flux/stores/focused-category-store'
  FocusedContentStore: require '../src/flux/stores/focused-content-store'
  FocusedContactsStore: require '../src/flux/stores/focused-contacts-store'
  FileUploadStore: require '../src/flux/stores/file-upload-store'
  FileDownloadStore: require '../src/flux/stores/file-download-store'
  UnreadCountStore: require '../src/flux/stores/unread-count-store'

  # Errors
  APIError: APIError
  OfflineError: OfflineError
  TimeoutError: TimeoutError

  ## TODO move to inside of individual Salesforce package. See https://trello.com/c/tLAGLyeb/246-move-salesforce-models-into-individual-package-db-models-for-packages-various-refactors
  SalesforceAssociation: require '../src/flux/models/salesforce-association'
  SalesforceSearchResult: require '../src/flux/models/salesforce-search-result'
  SalesforceObject: require '../src/flux/models/salesforce-object'
  SalesforceSchema: require '../src/flux/models/salesforce-schema'

  # Services
  QuotedPlainTextParser: require '../src/services/quoted-plain-text-parser'
  QuotedHTMLParser: require '../src/services/quoted-html-parser'

# Also include all of the model classes
for key, klass of Utils.modelClassMap()
  Exports[klass.name] = klass

module.exports = Exports
