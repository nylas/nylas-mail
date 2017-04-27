/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
import TaskRegistry from '../registries/task-registry'
import StoreRegistry from '../registries/store-registry'
import DatabaseObjectRegistry from '../registries/database-object-registry'

const resolveExport = (requireValue) => {
  return requireValue.default || requireValue;
}

// This module exports an empty object, with a ton of defined properties that
// `require` files the first time they're called.
module.exports = exports = window.$n = {};

// Calling require() repeatedly isn't free! Even though it has it's own cache,
// it still needs to resolve the path to a file based on the current __dirname,
// match it against it's cache, etc. We can shortcut all this work.
const RequireCache = {};

// Will lazy load when requested
const lazyLoadWithGetter = (prop, getter) => {
  const key = `${prop}`;

  if (exports[key]) {
    throw new Error(`Fatal error: Duplicate entry in nylas-exports: ${key}`)
  }
  Object.defineProperty(exports, prop, {
    get: () => {
      RequireCache[key] = RequireCache[key] || getter();
      return RequireCache[key];
    },
    enumerable: true,
  });
}

const lazyLoad = (prop, path) => {
  lazyLoadWithGetter(prop, () => resolveExport(require(`../${path}`)));
};

const lazyLoadAndRegisterStore = (klassName, path) => {
  lazyLoad(klassName, `flux/stores/${path}`);
  StoreRegistry.register(klassName, () => exports[klassName]);
}

const lazyLoadAndRegisterModel = (klassName, path) => {
  lazyLoad(klassName, `flux/models/${path}`);
  DatabaseObjectRegistry.register(klassName, () => exports[klassName]);
};

const lazyLoadAndRegisterTask = (klassName, path) => {
  lazyLoad(klassName, `flux/tasks/${path}`);
  TaskRegistry.register(klassName, () => exports[klassName]);
};

const lazyLoadDeprecated = (prop, path, {instead} = {}) => {
  const {deprecate} = require('../deprecate-utils');
  Object.defineProperty(exports, prop, {
    get: deprecate(prop, instead, exports, () => {
      return resolveExport(require(`../${path}`));
    }),
    enumerable: true,
  });
};

// Actions
lazyLoad(`Actions`, 'flux/actions');

// API Endpoints
lazyLoad(`NylasAPI`, 'flux/nylas-api');
lazyLoad(`N1CloudAPI`, 'n1-cloud-api');
lazyLoad(`EdgehillAPI`, 'flux/edgehill-api');
lazyLoad(`LegacyEdgehillAPI`, 'flux/legacy-edgehill-api');
lazyLoad(`NylasAPIHelpers`, 'flux/nylas-api-helpers');
lazyLoad(`NylasAPIRequest`, 'flux/nylas-api-request');
lazyLoad(`NylasLongConnection`, 'flux/nylas-long-connection');

// The Database
lazyLoad(`Matcher`, 'flux/attributes/matcher');
lazyLoad(`DatabaseStore`, 'flux/stores/database-store');
lazyLoad(`QueryResultSet`, 'flux/models/query-result-set');
lazyLoad(`QuerySubscription`, 'flux/models/query-subscription');
lazyLoad(`CalendarDataSource`, 'components/nylas-calendar/calendar-data-source');
lazyLoad(`DatabaseWriter`, 'flux/stores/database-writer');
lazyLoad(`MutableQueryResultSet`, 'flux/models/mutable-query-result-set');
lazyLoad(`QuerySubscriptionPool`, 'flux/models/query-subscription-pool');
lazyLoad(`ObservableListDataSource`, 'flux/stores/observable-list-data-source');
lazyLoad(`MutableQuerySubscription`, 'flux/models/mutable-query-subscription');

// Database Objects
exports.DatabaseObjectRegistry = DatabaseObjectRegistry;
lazyLoad(`Model`, 'flux/models/model');
lazyLoad(`Attributes`, 'flux/attributes');
lazyLoadAndRegisterModel(`File`, 'file');
lazyLoadAndRegisterModel(`Event`, 'event');
lazyLoadAndRegisterModel(`Label`, 'label');
lazyLoadAndRegisterModel(`Folder`, 'folder');
lazyLoadAndRegisterModel(`Thread`, 'thread');
lazyLoadAndRegisterModel(`Account`, 'account');
lazyLoadAndRegisterModel(`Message`, 'message');
lazyLoadAndRegisterModel(`Contact`, 'contact');
lazyLoadAndRegisterModel(`Category`, 'category');
lazyLoadAndRegisterModel(`Calendar`, 'calendar');
lazyLoadAndRegisterModel(`JSONBlob`, 'json-blob');
lazyLoadAndRegisterModel(`ProviderSyncbackRequest`, 'provider-syncback-request');

// Search Query Interfaces
lazyLoad(`SearchQueryAST`, 'services/search/search-query-ast');
lazyLoad(`SearchQueryParser`, 'services/search/search-query-parser');
lazyLoad(`IMAPSearchQueryBackend`, 'services/search/search-query-backend-imap');

// Tasks
exports.TaskRegistry = TaskRegistry;
lazyLoad(`Task`, 'flux/tasks/task');
lazyLoad(`TaskFactory`, 'flux/tasks/task-factory');
lazyLoadAndRegisterTask(`EventRSVPTask`, 'event-rsvp-task');
lazyLoadAndRegisterTask(`BaseDraftTask`, 'base-draft-task');
lazyLoadAndRegisterTask(`SendDraftTask`, 'send-draft-task');
lazyLoadAndRegisterTask(`ChangeMailTask`, 'change-mail-task');
lazyLoadAndRegisterTask(`DestroyDraftTask`, 'destroy-draft-task');
lazyLoadAndRegisterTask(`ChangeLabelsTask`, 'change-labels-task');
lazyLoadAndRegisterTask(`ChangeFolderTask`, 'change-folder-task');
lazyLoadAndRegisterTask(`ChangeUnreadTask`, 'change-unread-task');
lazyLoadAndRegisterTask(`DestroyModelTask`, 'destroy-model-task');
lazyLoadAndRegisterTask(`ChangeStarredTask`, 'change-starred-task');
lazyLoadAndRegisterTask(`SyncbackModelTask`, 'syncback-model-task');
lazyLoadAndRegisterTask(`SyncbackEventTask`, 'syncback-event-task');
lazyLoadAndRegisterTask(`DestroyCategoryTask`, 'destroy-category-task');
lazyLoadAndRegisterTask(`SyncbackCategoryTask`, 'syncback-category-task');
lazyLoadAndRegisterTask(`SyncbackMetadataTask`, 'syncback-metadata-task');
lazyLoadAndRegisterTask(`PerformSendActionTask`, 'perform-send-action-task');
lazyLoadAndRegisterTask(`ReprocessMailRulesTask`, 'reprocess-mail-rules-task');
lazyLoadAndRegisterTask(`SendFeatureUsageEventTask`, 'send-feature-usage-event-task');
lazyLoadAndRegisterTask(`EnsureMessageInSentFolderTask`, 'ensure-message-in-sent-folder-task');

// Stores
// These need to be required immediately since some Stores are
// listen-only and not explicitly required from anywhere. Stores
// currently set themselves up on require.
lazyLoadAndRegisterStore(`TaskQueue`, 'task-queue');
lazyLoadAndRegisterStore(`BadgeStore`, 'badge-store');
lazyLoadAndRegisterStore(`DraftStore`, 'draft-store');
lazyLoadAndRegisterStore(`ModalStore`, 'modal-store');
lazyLoadAndRegisterStore(`OutboxStore`, 'outbox-store');
lazyLoadAndRegisterStore(`PopoverStore`, 'popover-store');
lazyLoadAndRegisterStore(`AccountStore`, 'account-store');
lazyLoadAndRegisterStore(`SignatureStore`, 'signature-store');
lazyLoadAndRegisterStore(`MessageStore`, 'message-store');
lazyLoadAndRegisterStore(`ContactStore`, 'contact-store');
lazyLoadAndRegisterStore(`IdentityStore`, 'identity-store');
lazyLoadAndRegisterStore(`MetadataStore`, 'metadata-store');
lazyLoadAndRegisterStore(`CategoryStore`, 'category-store');
lazyLoadAndRegisterStore(`UndoRedoStore`, 'undo-redo-store');
lazyLoadAndRegisterStore(`WorkspaceStore`, 'workspace-store');
lazyLoadAndRegisterStore(`MailRulesStore`, 'mail-rules-store');
lazyLoadAndRegisterStore(`FileUploadStore`, 'file-upload-store');
lazyLoadAndRegisterStore(`SendActionsStore`, 'send-actions-store');
lazyLoadAndRegisterStore(`FeatureUsageStore`, 'feature-usage-store');
lazyLoadAndRegisterStore(`ThreadCountsStore`, 'thread-counts-store');
lazyLoadAndRegisterStore(`FileDownloadStore`, 'file-download-store');
lazyLoadAndRegisterStore(`OnlineStatusStore`, 'online-status-store');
lazyLoadAndRegisterStore(`UpdateChannelStore`, 'update-channel-store');
lazyLoadAndRegisterStore(`PreferencesUIStore`, 'preferences-ui-store');
lazyLoadAndRegisterStore(`FocusedContentStore`, 'focused-content-store');
lazyLoadAndRegisterStore(`MessageBodyProcessor`, 'message-body-processor');
lazyLoadAndRegisterStore(`FocusedContactsStore`, 'focused-contacts-store');
lazyLoadAndRegisterStore(`DeltaConnectionStore`, 'delta-connection-store');
lazyLoadAndRegisterStore(`TaskQueueStatusStore`, 'task-queue-status-store');
lazyLoadAndRegisterStore(`FolderSyncProgressStore`, 'folder-sync-progress-store');
lazyLoadAndRegisterStore(`ThreadListActionsStore`, 'thread-list-actions-store');
lazyLoadAndRegisterStore(`FocusedPerspectiveStore`, 'focused-perspective-store');
lazyLoadAndRegisterStore(`SearchableComponentStore`, 'searchable-component-store');
lazyLoad(`CustomContenteditableComponents`, 'components/overlaid-components/custom-contenteditable-components');

lazyLoad(`ServiceRegistry`, `registries/service-registry`);

// Decorators
lazyLoad(`InflatesDraftClientId`, 'decorators/inflates-draft-client-id');

// Extensions
lazyLoad(`ExtensionRegistry`, 'registries/extension-registry');
lazyLoad(`ComposerExtension`, 'extensions/composer-extension');
lazyLoad(`MessageViewExtension`, 'extensions/message-view-extension');
lazyLoad(`ContenteditableExtension`, 'extensions/contenteditable-extension');

// 3rd party libraries
lazyLoadWithGetter(`Rx`, () => require('rx-lite'));
lazyLoadWithGetter(`React`, () => require('react'));
lazyLoadWithGetter(`Reflux`, () => require('reflux'));
lazyLoadWithGetter(`ReactDOM`, () => require('react-dom'));
lazyLoadWithGetter(`ReactTestUtils`, () => require('react-addons-test-utils'));

// React Components
lazyLoad(`ComponentRegistry`, 'registries/component-registry');
lazyLoad(`PriorityUICoordinator`, 'priority-ui-coordinator');

// Utils
lazyLoad(`Utils`, 'flux/models/utils');
lazyLoad(`DOMUtils`, 'dom-utils');
lazyLoad(`DateUtils`, 'date-utils');
lazyLoad(`FsUtils`, 'fs-utils');
lazyLoad(`CanvasUtils`, 'canvas-utils');
lazyLoad(`RegExpUtils`, 'regexp-utils');
lazyLoad(`MenuHelpers`, 'menu-helpers');
lazyLoad(`DeprecateUtils`, 'deprecate-utils');
lazyLoad(`VirtualDOMUtils`, 'virtual-dom-utils');
lazyLoad(`Spellchecker`, 'spellchecker');
lazyLoad(`DraftHelpers`, 'flux/stores/draft-helpers');
lazyLoad(`MessageUtils`, 'flux/models/message-utils');
lazyLoad(`EditorAPI`, 'components/contenteditable/editor-api');

// Services
lazyLoad(`KeyManager`, 'key-manager');
lazyLoad(`SoundRegistry`, 'registries/sound-registry');
lazyLoad(`MailRulesTemplates`, 'mail-rules-templates');
lazyLoad(`MailRulesProcessor`, 'mail-rules-processor');
lazyLoad(`MailboxPerspective`, 'mailbox-perspective');
lazyLoad(`DeltaProcessor`, 'services/delta-processor');
lazyLoad(`NativeNotifications`, 'native-notifications');
lazyLoad(`ModelSearchIndexer`, 'services/model-search-indexer');
lazyLoad(`SearchIndexScheduler`, 'services/search-index-scheduler');
lazyLoad(`SanitizeTransformer`, 'services/sanitize-transformer');
lazyLoad(`QuotedHTMLTransformer`, 'services/quoted-html-transformer');
lazyLoad(`InlineStyleTransformer`, 'services/inline-style-transformer');
lazyLoad(`SearchableComponentMaker`, 'searchable-components/searchable-component-maker');
lazyLoad(`QuotedPlainTextTransformer`, 'services/quoted-plain-text-transformer');
lazyLoad(`BatteryStatusManager`, 'services/battery-status-manager');

// Errors
lazyLoadWithGetter(`APIError`, () => require('../flux/errors').APIError);

// Process Internals
lazyLoad(`DefaultClientHelper`, 'default-client-helper');
lazyLoad(`BufferedProcess`, 'buffered-process');
lazyLoad(`SystemStartService`, 'system-start-service');
lazyLoadWithGetter(`APMWrapper`, () => require('../apm-wrapper'));

// Testing
lazyLoadWithGetter(`NylasTestUtils`, () => require('../../spec/nylas-test-utils'));

// Deprecated
lazyLoadDeprecated(`QuotedHTMLParser`, 'services/quoted-html-transformer', {
  instead: 'QuotedHTMLTransformer',
});
lazyLoadDeprecated(`DraftStoreExtension`, 'flux/stores/draft-store-extension', {
  instead: 'ComposerExtension',
});
lazyLoadDeprecated(`MessageStoreExtension`, 'flux/stores/message-store-extension', {
  instead: 'MessageViewExtension',
});
