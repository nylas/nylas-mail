Task = null
Model = null
TaskRegistry = null
DatabaseObjectRegistry = null

class NylasExports
  @registerSerializable = (exported) ->
    if exported.prototype
      Task ?= require '../flux/tasks/task'
      Model ?= require '../flux/models/model'
      if exported.prototype instanceof Model
        DatabaseObjectRegistry ?= require '../database-object-registry'
        DatabaseObjectRegistry.register(exported)
      else if exported.prototype instanceof Task
        TaskRegistry ?= require '../task-registry'
        TaskRegistry.register(exported)

  @get = (prop, get) ->
    Object.defineProperty @, prop, {get, enumerable: true}

  # Will lazy load when requested
  @load = (prop, path) ->
    Object.defineProperty @, prop,
      get: ->
        exported = require "../#{path}"
        NylasExports.registerSerializable(exported)
        return exported
      enumerable: true

  # Will require immediately
  @require = (prop, path) ->
    exported = require "../#{path}"
    NylasExports.registerSerializable(exported)
    @[prop] = exported

  # Actions
  @load "Actions", 'flux/actions'

  # API Endpoints
  @load "NylasAPI", 'flux/nylas-api'
  @load "NylasSyncStatusStore", 'flux/stores/nylas-sync-status-store'
  @load "EdgehillAPI", 'flux/edgehill-api'

  # The Database
  @load "ModelView", 'flux/stores/model-view'
  @load "SearchView", 'flux/stores/search-view'
  @load "DatabaseView", 'flux/stores/database-view'
  @load "DatabaseStore", 'flux/stores/database-store'

  # Database Objects
  # These need to be required immeidatley to populated the
  # DatabaseObjectRegistry so we know what Database Tables to construct
  @require "File", 'flux/models/file'
  @require "Event", 'flux/models/event'
  @require "Label", 'flux/models/label'
  @require "Folder", 'flux/models/folder'
  @require "Thread", 'flux/models/thread'
  @require "Account", 'flux/models/account'
  @require "Message", 'flux/models/message'
  @require "Contact", 'flux/models/contact'
  @require "Category", 'flux/models/category'
  @require "Calendar", 'flux/models/calendar'
  @require "Metadata", 'flux/models/metadata'
  @require "DatabaseObjectRegistry", "database-object-registry"
  @require "MailViewFilter", 'mail-view-filter'

  # Exported so 3rd party packages can subclass Model
  @load "Model", 'flux/models/model'
  @load "Attributes", 'flux/attributes'

  # The Task Queue
  @require "Task", 'flux/tasks/task'
  @require "TaskRegistry", "task-registry"
  @require "TaskQueue", 'flux/stores/task-queue'
  @require "TaskFactory", 'flux/tasks/task-factory'
  @load    "TaskQueueStatusStore", 'flux/stores/task-queue-status-store'
  @require "UndoRedoStore", 'flux/stores/undo-redo-store'

  # Tasks
  # These need to be required immediately to populate the TaskRegistry so
  # we know how to deserialized saved or IPC-sent tasks.
  @require "EventRSVPTask", 'flux/tasks/event-rsvp'
  @require "SendDraftTask", 'flux/tasks/send-draft'
  @require "FileUploadTask", 'flux/tasks/file-upload-task'
  @require "DestroyDraftTask", 'flux/tasks/destroy-draft'
  @require "ChangeLabelsTask", 'flux/tasks/change-labels-task'
  @require "ChangeFolderTask", 'flux/tasks/change-folder-task'
  @require "SyncbackCategoryTask", 'flux/tasks/syncback-category-task'
  @require "DestroyCategoryTask", 'flux/tasks/destroy-category-task'
  @require "ChangeUnreadTask", 'flux/tasks/change-unread-task'
  @require "SyncbackDraftTask", 'flux/tasks/syncback-draft'
  @require "ChangeStarredTask", 'flux/tasks/change-starred-task'
  @require "CreateMetadataTask", 'flux/tasks/create-metadata-task'
  @require "DestroyMetadataTask", 'flux/tasks/destroy-metadata-task'

  # Stores
  # These need to be required immediately since some Stores are
  # listen-only and not explicitly required from anywhere. Stores
  # currently set themselves up on require.
  @require "DraftStore", 'flux/stores/draft-store'
  @require "AccountStore", 'flux/stores/account-store'
  @require "MessageStore", 'flux/stores/message-store'
  @require "ContactStore", 'flux/stores/contact-store'
  @require "CategoryStore", 'flux/stores/category-store'
  @require "WorkspaceStore", 'flux/stores/workspace-store'
  @require "DraftCountStore", 'flux/stores/draft-count-store'
  @require "FileUploadStore", 'flux/stores/file-upload-store'
  @require "ThreadCountsStore", 'flux/stores/thread-counts-store'
  @require "UnreadBadgeStore", 'flux/stores/unread-badge-store'
  @require "FileDownloadStore", 'flux/stores/file-download-store'
  @require "DraftStoreExtension", 'flux/stores/draft-store-extension'
  @require "FocusedContentStore", 'flux/stores/focused-content-store'
  @require "FocusedMailViewStore", 'flux/stores/focused-mail-view-store'
  @require "FocusedContactsStore", 'flux/stores/focused-contacts-store'
  @require "MessageBodyProcessor", 'flux/stores/message-body-processor'
  @require "MessageStoreExtension", 'flux/stores/message-store-extension'
  @require "PreferencesUIStore", 'flux/stores/preferences-ui-store'

  # React Components
  @get "React", -> require 'react' # Our version of React for 3rd party use
  @load "ReactRemote", 'react-remote/react-remote-parent'
  @load "ComponentRegistry", 'component-registry'
  @load "PriorityUICoordinator", 'priority-ui-coordinator'

  # Utils
  @load "Utils", 'flux/models/utils'
  @load "DOMUtils", 'dom-utils'
  @load "CanvasUtils", 'canvas-utils'
  @load "RegExpUtils", 'regexp-utils'
  @load "MessageUtils", 'flux/models/message-utils'

  # Services
  @load "UndoManager", 'undo-manager'
  @load "SoundRegistry", 'sound-registry'
  @load "QuotedHTMLParser", 'services/quoted-html-parser'
  @load "QuotedPlainTextParser", 'services/quoted-plain-text-parser'
  @load "NativeNotifications", 'native-notifications'

  # Errors
  @get "APIError", -> require('../flux/errors').APIError
  @get "OfflineError", -> require('../flux/errors').OfflineError
  @get "TimeoutError", -> require('../flux/errors').TimeoutError

  # Process Internals
  @load "LaunchServices", 'launch-services'
  @load "BufferedProcess", 'buffered-process'
  @get "APMWrapper", -> require('../apm-wrapper')

  # Contenteditable
  @load "ContenteditablePlugin", 'components/contenteditable/contenteditable-plugin'

  # Testing
  @get "NylasTestUtils", -> require '../../spec/nylas-test-utils'

module.exports = NylasExports
