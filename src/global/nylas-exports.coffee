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

  @requireDeprecated = (prop, path, {instead} = {}) ->
    {deprecate} = require '../deprecate-utils'
    Object.defineProperty @, prop,
      get: deprecate prop, instead, @, ->
        exported = require "../#{path}"
        NylasExports.registerSerializable(exported)
        return exported
      enumerable: true

  # Make sure our custom observable helpers are defined immediately
  # (fromStore, fromQuery, etc...)
  require 'nylas-observables'

  # Actions
  @load "Actions", 'flux/actions'

  # API Endpoints
  @load "nylasRequest", 'nylas-request' # An extend `request` module
  @load "NylasAPI", 'flux/nylas-api'
  @load "NylasSyncStatusStore", 'flux/stores/nylas-sync-status-store'
  @load "EdgehillAPI", 'flux/edgehill-api'

  # The Database
  @load "Matcher", 'flux/attributes/matcher'
  @load "DatabaseStore", 'flux/stores/database-store'
  @load "DatabaseTransaction", 'flux/stores/database-transaction'
  @load "QueryResultSet", 'flux/models/query-result-set'
  @load "MutableQueryResultSet", 'flux/models/mutable-query-result-set'
  @load "ObservableListDataSource", 'flux/stores/observable-list-data-source'
  @load "CalendarDataSource", 'components/nylas-calendar/calendar-data-source'
  @load "QuerySubscription", 'flux/models/query-subscription'
  @load "MutableQuerySubscription", 'flux/models/mutable-query-subscription'
  @load "QuerySubscriptionPool", 'flux/models/query-subscription-pool'

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
  @require "JSONBlob", 'flux/models/json-blob'
  @require "DatabaseObjectRegistry", "database-object-registry"
  @require "MailboxPerspective", 'mailbox-perspective'

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
  @require "EventRSVPTask", 'flux/tasks/event-rsvp-task'
  @require "SendDraftTask", 'flux/tasks/send-draft-task'
  @require "DestroyDraftTask", 'flux/tasks/destroy-draft-task'
  @require "ChangeMailTask", 'flux/tasks/change-mail-task'
  @require "ChangeLabelsTask", 'flux/tasks/change-labels-task'
  @require "ChangeFolderTask", 'flux/tasks/change-folder-task'
  @require "SyncbackCategoryTask", 'flux/tasks/syncback-category-task'
  @require "DestroyCategoryTask", 'flux/tasks/destroy-category-task'
  @require "ChangeUnreadTask", 'flux/tasks/change-unread-task'
  @require "SyncbackDraftFilesTask", 'flux/tasks/syncback-draft-files-task'
  @require "SyncbackDraftTask", 'flux/tasks/syncback-draft-task'
  @require "ChangeStarredTask", 'flux/tasks/change-starred-task'
  @require "DestroyModelTask", 'flux/tasks/destroy-model-task'
  @require "SyncbackModelTask", 'flux/tasks/syncback-model-task'
  @require "SyncbackMetadataTask", 'flux/tasks/syncback-metadata-task'
  @require "ReprocessMailRulesTask", 'flux/tasks/reprocess-mail-rules-task'
  @require "RegisterDraftForPluginTask", 'flux/tasks/register-draft-for-plugin-task'

  # Stores
  # These need to be required immediately since some Stores are
  # listen-only and not explicitly required from anywhere. Stores
  # currently set themselves up on require.
  @require "DraftStore", 'flux/stores/draft-store'
  @require "OutboxStore", 'flux/stores/outbox-store'
  @require "AccountStore", 'flux/stores/account-store'
  @require "MessageStore", 'flux/stores/message-store'
  @require "MetadataStore", 'flux/stores/metadata-store'
  @require "ContactStore", 'flux/stores/contact-store'
  @require "CategoryStore", 'flux/stores/category-store'
  @require "WorkspaceStore", 'flux/stores/workspace-store'
  @require "FileUploadStore", 'flux/stores/file-upload-store'
  @require "MailRulesStore", 'flux/stores/mail-rules-store'
  @require "ThreadCountsStore", 'flux/stores/thread-counts-store'
  @require "BadgeStore", 'flux/stores/badge-store'
  @require "FileDownloadStore", 'flux/stores/file-download-store'
  @require "FocusedContentStore", 'flux/stores/focused-content-store'
  @require "FocusedPerspectiveStore", 'flux/stores/focused-perspective-store'
  @require "FocusedContactsStore", 'flux/stores/focused-contacts-store'
  @require "PreferencesUIStore", 'flux/stores/preferences-ui-store'
  @require "PopoverStore", 'flux/stores/popover-store'
  @require "ModalStore", 'flux/stores/modal-store'
  @require "SearchableComponentStore", 'flux/stores/searchable-component-store'
  @require "MessageBodyProcessor", 'flux/stores/message-body-processor'
  @require "MailRulesTemplates", 'mail-rules-templates'
  @require "MailRulesProcessor", 'mail-rules-processor'

  # Deprecated
  @requireDeprecated "DraftStoreExtension", 'flux/stores/draft-store-extension',
    instead: 'ComposerExtension'
  @requireDeprecated "MessageStoreExtension", 'flux/stores/message-store-extension',
    instead: 'MessageViewExtension'

  # Extensions
  @require "ExtensionRegistry", 'extension-registry'
  @require "ContenteditableExtension", 'extensions/contenteditable-extension'
  @require "ComposerExtension", 'extensions/composer-extension'
  @require "MessageViewExtension", 'extensions/message-view-extension'

  # Libraries
  @get "React", -> require 'react' # Our version of React for 3rd party use
  @get "ReactDOM", -> require 'react-dom'
  @get "Reflux", -> require 'reflux'
  @get "Rx", -> require 'rx-lite'
  @get "Keytar", -> require 'keytar' # atom-keytar access through native module

  # React Components
  @load "ReactRemote", 'react-remote/react-remote-parent'
  @load "ComponentRegistry", 'component-registry'
  @load "PriorityUICoordinator", 'priority-ui-coordinator'

  # Utils
  @load "DeprecateUtils", 'deprecate-utils'
  @load "Utils", 'flux/models/utils'
  @load "DOMUtils", 'dom-utils'
  @load "VirtualDOMUtils", 'virtual-dom-utils'
  @load "CanvasUtils", 'canvas-utils'
  @load "RegExpUtils", 'regexp-utils'
  @load "DateUtils", 'date-utils'
  @load "MenuHelpers", 'menu-helpers'
  @load "MessageUtils", 'flux/models/message-utils'
  @load "NylasSpellchecker", 'nylas-spellchecker'

  # Services
  @load "UndoManager", 'undo-manager'
  @load "SoundRegistry", 'sound-registry'
  @load "NativeNotifications", 'native-notifications'

  @load "SearchableComponentMaker", 'searchable-components/searchable-component-maker'

  @load "QuotedHTMLTransformer", 'services/quoted-html-transformer'
  @load "QuotedPlainTextTransformer", 'services/quoted-plain-text-transformer'
  @load "SanitizeTransformer", 'services/sanitize-transformer'
  @load "InlineStyleTransformer", 'services/inline-style-transformer'
  @requireDeprecated "QuotedHTMLParser", 'services/quoted-html-transformer',
    instead: 'QuotedHTMLTransformer'

  # Errors
  @get "APIError", -> require('../flux/errors').APIError
  @get "TimeoutError", -> require('../flux/errors').TimeoutError

  # Process Internals
  @load "LaunchServices", 'launch-services'
  @load "SystemStartService", 'system-start-service'
  @load "BufferedProcess", 'buffered-process'
  @get "APMWrapper", -> require('../apm-wrapper')

  # Testing
  @get "NylasTestUtils", -> require '../../spec/nylas-test-utils'

window.$n = NylasExports
module.exports = NylasExports
