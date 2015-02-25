# All Inbox Globals go here.

module.exports =

  # The Task Queue
  Task: require '../src/flux/tasks/task'
  TaskQueue: require '../src/flux/stores/task-queue'

  # The Database
  DatabaseStore: require '../src/flux/stores/database-store'

  # Actions
  Actions: require '../src/flux/actions'

  # API Endpoints
  EdgehillAPI: require '../src/flux/edgehill-api'

  # Testing
  InboxTestUtils: require '../spec-inbox/test_utils'

  # Component Registry
  ComponentRegistry: require '../src/component-registry'

  # Utils
  Utils: require '../src/flux/models/utils'

  # Models
  Tag: require '../src/flux/models/tag'
  File: require '../src/flux/models/file'
  Thread: require '../src/flux/models/thread'
  Contact: require '../src/flux/models/contact'
  Message: require '../src/flux/models/message'
  Namespace: require '../src/flux/models/namespace'
  Calendar: require '../src/flux/models/calendar'
  Event: require '../src/flux/models/event'
  SalesforceTask: require '../src/flux/models/salesforce-task'

  # Stores
  DraftStore: require '../src/flux/stores/draft-store'
  ThreadStore: require '../src/flux/stores/thread-store'
  MessageStore: require '../src/flux/stores/message-store'
  ContactStore: require '../src/flux/stores/contact-store'
  NamespaceStore: require '../src/flux/stores/namespace-store'
  FileUploadStore: require '../src/flux/stores/file-upload-store'
  FileDownloadStore: require '../src/flux/stores/file-download-store'

  ## TODO move to inside of individual Salesforce package. See https://trello.com/c/tLAGLyeb/246-move-salesforce-models-into-individual-package-db-models-for-packages-various-refactors
  SalesforceAssociation: require '../src/flux/models/salesforce-association'
  SalesforceContact: require '../src/flux/models/salesforce-contact'
