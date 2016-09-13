TaskRegistry = require('../task-registry').default
StoreRegistry = require('../store-registry').default
DatabaseObjectRegistry = require('../database-object-registry').default

# Calling require() repeatedly isn't free! Even though it has it's own cache,
# it still needs to resolve the path to a file based on the current __dirname,
# match it against it's cache, etc. We can shortcut all this work.
RequireCache = {}

class NylasExports

  @default = (requireValue) -> requireValue.default ? requireValue

  # Will lazy load when requested
  @lazyLoad = (prop, path) ->
    Object.defineProperty @, prop,
      get: ->
        key = "#{prop}#{path}"
        RequireCache[key] = RequireCache[key] || NylasExports.default(require("../#{path}"))
        return RequireCache[key]
      enumerable: true

  @lazyLoadCustomGetter = (prop, get) ->
    Object.defineProperty @, prop, {get, enumerable: true}

  @lazyLoadAndRegisterStore = (klassName, path) ->
    constructorFactory = ->
      NylasExports.default(require("../flux/stores/#{path}"))
    StoreRegistry.register(klassName, constructorFactory)
    @lazyLoad(klassName, "flux/stores/#{path}")

  @lazyLoadAndRegisterModel = (klassName, path) ->
    constructorFactory = ->
      NylasExports.default(require("../flux/models/#{path}"))
    DatabaseObjectRegistry.register(klassName, constructorFactory)
    @lazyLoad(klassName, "flux/models/#{path}")

  @lazyLoadAndRegisterTask = (klassName, path) ->
    constructorFactory = ->
      NylasExports.default(require("../flux/tasks/#{path}"))
    TaskRegistry.register(klassName, constructorFactory)
    @lazyLoad(klassName, "flux/tasks/#{path}")

  @lazyLoadDeprecated = (prop, path, {instead} = {}) ->
    {deprecate} = require '../deprecate-utils'
    Object.defineProperty @, prop,
      get: deprecate prop, instead, @, ->
        NylasExports.default(require("../#{path}"))
      enumerable: true

  # Actions
  @lazyLoad "Actions", 'flux/actions'

  # API Endpoints
  @lazyLoad "NylasAPI", 'flux/nylas-api'
  @lazyLoad "NylasAPIRequest", 'flux/nylas-api-request'
  @lazyLoad "EdgehillAPI", 'flux/edgehill-api'
  @lazyLoad "NylasLongConnection", 'flux/nylas-long-connection'
  @lazyLoad "NylasSyncStatusStore", 'flux/stores/nylas-sync-status-store'

  # The Database
  @lazyLoad "Matcher", 'flux/attributes/matcher'
  @lazyLoad "DatabaseStore", 'flux/stores/database-store'
  @lazyLoad "QueryResultSet", 'flux/models/query-result-set'
  @lazyLoad "QuerySubscription", 'flux/models/query-subscription'
  @lazyLoad "CalendarDataSource", 'components/nylas-calendar/calendar-data-source'
  @lazyLoad "DatabaseTransaction", 'flux/stores/database-transaction'
  @lazyLoad "MutableQueryResultSet", 'flux/models/mutable-query-result-set'
  @lazyLoad "QuerySubscriptionPool", 'flux/models/query-subscription-pool'
  @lazyLoad "ObservableListDataSource", 'flux/stores/observable-list-data-source'
  @lazyLoad "MutableQuerySubscription", 'flux/models/mutable-query-subscription'

  # Database Objects
  @DatabaseObjectRegistry = DatabaseObjectRegistry
  @lazyLoad "Model", 'flux/models/model'
  @lazyLoad "Attributes", 'flux/attributes'
  @lazyLoadAndRegisterModel "File", 'file'
  @lazyLoadAndRegisterModel "Event", 'event'
  @lazyLoadAndRegisterModel "Label", 'label'
  @lazyLoadAndRegisterModel "Folder", 'folder'
  @lazyLoadAndRegisterModel "Thread", 'thread'
  @lazyLoadAndRegisterModel "Account", 'account'
  @lazyLoadAndRegisterModel "Message", 'message'
  @lazyLoadAndRegisterModel "Contact", 'contact'
  @lazyLoadAndRegisterModel "Category", 'category'
  @lazyLoadAndRegisterModel "Calendar", 'calendar'
  @lazyLoadAndRegisterModel "JSONBlob", 'json-blob'

  # Tasks
  @TaskRegistry = TaskRegistry
  @lazyLoad "Task", 'flux/tasks/task'
  @lazyLoad "TaskFactory", 'flux/tasks/task-factory'
  @lazyLoadAndRegisterTask "EventRSVPTask", 'event-rsvp-task'
  @lazyLoadAndRegisterTask "BaseDraftTask", 'base-draft-task'
  @lazyLoadAndRegisterTask "SendDraftTask", 'send-draft-task'
  @lazyLoadAndRegisterTask "MultiSendToIndividualTask", 'multi-send-to-individual-task'
  @lazyLoadAndRegisterTask "MultiSendSessionCloseTask", 'multi-send-session-close-task'
  @lazyLoadAndRegisterTask "ChangeMailTask", 'change-mail-task'
  @lazyLoadAndRegisterTask "DestroyDraftTask", 'destroy-draft-task'
  @lazyLoadAndRegisterTask "ChangeLabelsTask", 'change-labels-task'
  @lazyLoadAndRegisterTask "ChangeFolderTask", 'change-folder-task'
  @lazyLoadAndRegisterTask "ChangeUnreadTask", 'change-unread-task'
  @lazyLoadAndRegisterTask "DestroyModelTask", 'destroy-model-task'
  @lazyLoadAndRegisterTask "SyncbackDraftTask", 'syncback-draft-task'
  @lazyLoadAndRegisterTask "ChangeStarredTask", 'change-starred-task'
  @lazyLoadAndRegisterTask "SyncbackModelTask", 'syncback-model-task'
  @lazyLoadAndRegisterTask "DestroyCategoryTask", 'destroy-category-task'
  @lazyLoadAndRegisterTask "SyncbackCategoryTask", 'syncback-category-task'
  @lazyLoadAndRegisterTask "SyncbackMetadataTask", 'syncback-metadata-task'
  @lazyLoadAndRegisterTask "SyncbackDraftFilesTask", 'syncback-draft-files-task'
  @lazyLoadAndRegisterTask "ReprocessMailRulesTask", 'reprocess-mail-rules-task'
  @lazyLoadAndRegisterTask "NotifyPluginsOfSendTask", 'notify-plugins-of-send-task'

  # Stores
  # These need to be required immediately since some Stores are
  # listen-only and not explicitly required from anywhere. Stores
  # currently set themselves up on require.
  @lazyLoadAndRegisterStore "TaskQueue", 'task-queue'
  @lazyLoadAndRegisterStore "BadgeStore", 'badge-store'
  @lazyLoadAndRegisterStore "DraftStore", 'draft-store'
  @lazyLoadAndRegisterStore "ModalStore", 'modal-store'
  @lazyLoadAndRegisterStore "OutboxStore", 'outbox-store'
  @lazyLoadAndRegisterStore "PopoverStore", 'popover-store'
  @lazyLoadAndRegisterStore "AccountStore", 'account-store'
  @lazyLoadAndRegisterStore "SignatureStore", 'signature-store'
  @lazyLoadAndRegisterStore "MessageStore", 'message-store'
  @lazyLoadAndRegisterStore "ContactStore", 'contact-store'
  @lazyLoadAndRegisterStore "IdentityStore", 'identity-store'
  @lazyLoadAndRegisterStore "MetadataStore", 'metadata-store'
  @lazyLoadAndRegisterStore "CategoryStore", 'category-store'
  @lazyLoadAndRegisterStore "UndoRedoStore", 'undo-redo-store'
  @lazyLoadAndRegisterStore "WorkspaceStore", 'workspace-store'
  @lazyLoadAndRegisterStore "MailRulesStore", 'mail-rules-store'
  @lazyLoadAndRegisterStore "FileUploadStore", 'file-upload-store'
  @lazyLoadAndRegisterStore "ThreadCountsStore", 'thread-counts-store'
  @lazyLoadAndRegisterStore "FileDownloadStore", 'file-download-store'
  @lazyLoadAndRegisterStore "PreferencesUIStore", 'preferences-ui-store'
  @lazyLoadAndRegisterStore "FocusedContentStore", 'focused-content-store'
  @lazyLoadAndRegisterStore "MessageBodyProcessor", 'message-body-processor'
  @lazyLoadAndRegisterStore "FocusedContactsStore", 'focused-contacts-store'
  @lazyLoadAndRegisterStore "TaskQueueStatusStore", 'task-queue-status-store'
  @lazyLoadAndRegisterStore "FocusedPerspectiveStore", 'focused-perspective-store'
  @lazyLoadAndRegisterStore "SearchableComponentStore", 'searchable-component-store'
  @lazyLoad "CustomContenteditableComponents", 'components/overlaid-components/custom-contenteditable-components'

  @lazyLoad "ServiceRegistry", "service-registry"

  # Decorators
  @lazyLoad "InflatesDraftClientId", 'decorators/inflates-draft-client-id'

  # Extensions
  @lazyLoad "ExtensionRegistry", 'extension-registry'
  @lazyLoad "ComposerExtension", 'extensions/composer-extension'
  @lazyLoad "MessageViewExtension", 'extensions/message-view-extension'
  @lazyLoad "ContenteditableExtension", 'extensions/contenteditable-extension'

  # 3rd party libraries
  @lazyLoadCustomGetter "Rx", -> require 'rx-lite'
  @lazyLoadCustomGetter "React", -> require 'react'
  @lazyLoadCustomGetter "Reflux", -> require 'reflux'
  @lazyLoadCustomGetter "ReactDOM", -> require 'react-dom'
  @lazyLoadCustomGetter "ReactTestUtils", -> require 'react-addons-test-utils'
  @lazyLoadCustomGetter "Keytar", -> require 'keytar' # atom-keytar access through native module

  # React Components
  @lazyLoad "ComponentRegistry", 'component-registry'
  @lazyLoad "PriorityUICoordinator", 'priority-ui-coordinator'

  # Utils
  @lazyLoad "Utils", 'flux/models/utils'
  @lazyLoad "DOMUtils", 'dom-utils'
  @lazyLoad "DateUtils", 'date-utils'
  @lazyLoad "FsUtils", 'fs-utils'
  @lazyLoad "CanvasUtils", 'canvas-utils'
  @lazyLoad "RegExpUtils", 'regexp-utils'
  @lazyLoad "MenuHelpers", 'menu-helpers'
  @lazyLoad "DeprecateUtils", 'deprecate-utils'
  @lazyLoad "VirtualDOMUtils", 'virtual-dom-utils'
  @lazyLoad "NylasSpellchecker", 'nylas-spellchecker'
  @lazyLoad "DraftHelpers", 'flux/stores/draft-helpers'
  @lazyLoad "MessageUtils", 'flux/models/message-utils'
  @lazyLoad "EditorAPI", 'components/contenteditable/editor-api'

  # Services
  @lazyLoad "SoundRegistry", 'sound-registry'
  @lazyLoad "MailRulesTemplates", 'mail-rules-templates'
  @lazyLoad "MailRulesProcessor", 'mail-rules-processor'
  @lazyLoad "MailboxPerspective", 'mailbox-perspective'
  @lazyLoad "NativeNotifications", 'native-notifications'
  @lazyLoad "SanitizeTransformer", 'services/sanitize-transformer'
  @lazyLoad "QuotedHTMLTransformer", 'services/quoted-html-transformer'
  @lazyLoad "InlineStyleTransformer", 'services/inline-style-transformer'
  @lazyLoad "SearchableComponentMaker", 'searchable-components/searchable-component-maker'
  @lazyLoad "QuotedPlainTextTransformer", 'services/quoted-plain-text-transformer'

  # Errors
  @lazyLoadCustomGetter "APIError", -> require('../flux/errors').APIError
  @lazyLoadCustomGetter "TimeoutError", -> require('../flux/errors').TimeoutError

  # Process Internals
  @lazyLoad "LaunchServices", 'launch-services'
  @lazyLoad "BufferedProcess", 'buffered-process'
  @lazyLoad "SystemStartService", 'system-start-service'
  @lazyLoadCustomGetter "APMWrapper", -> require('../apm-wrapper')

  # Testing
  @lazyLoadCustomGetter "NylasTestUtils", -> require '../../spec/nylas-test-utils'

  # Deprecated
  @lazyLoadDeprecated "QuotedHTMLParser", 'services/quoted-html-transformer',
    instead: 'QuotedHTMLTransformer'
  @lazyLoadDeprecated "DraftStoreExtension", 'flux/stores/draft-store-extension',
    instead: 'ComposerExtension'
  @lazyLoadDeprecated "MessageStoreExtension", 'flux/stores/message-store-extension',
    instead: 'MessageViewExtension'

window.$n = NylasExports
module.exports = NylasExports
