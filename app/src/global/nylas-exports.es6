/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */
import DatabaseObjectRegistry from '../registries/database-object-registry'

// This module exports an empty object, with a ton of defined properties that
// `require` files the first time they're called.
module.exports = exports = window.$n = {};

const resolveExport = (requireValue) => {
  return requireValue.default || requireValue;
}

const lazyLoadWithGetter = (prop, getter) => {
  const key = `${prop}`;

  if (exports[key]) {
    throw new Error(`Fatal error: Duplicate entry in nylas-exports: ${key}`)
  }
  Object.defineProperty(exports, prop, {
    configurable: true,
    enumerable: true,
    get: () => {
      const value = getter();
      Object.defineProperty(exports, prop, { enumerable: true, value });
      return value;
    },
  });
}

const lazyLoad = (prop, path) => {
  lazyLoadWithGetter(prop, () => resolveExport(require(`../${path}`)));
};

const _resolveNow = [];
const load = (klassName, path) => {
  lazyLoad(klassName, path);
  _resolveNow.push(klassName);
}

const lazyLoadAndRegisterModel = (klassName, path) => {
  lazyLoad(klassName, `flux/models/${path}`);
  DatabaseObjectRegistry.register(klassName, () => exports[klassName]);
};

const lazyLoadAndRegisterTask = (klassName, path) => {
  lazyLoad(klassName, `flux/tasks/${path}`);
  DatabaseObjectRegistry.register(klassName, () => exports[klassName]);
};

// Actions
lazyLoad(`Actions`, 'flux/actions');

// API Endpoints
lazyLoad(`N1CloudAPI`, 'n1-cloud-api');
lazyLoad(`NylasAPIHelpers`, 'flux/nylas-api-helpers');
lazyLoad(`NylasAPIRequest`, 'flux/nylas-api-request');
lazyLoad(`MailsyncProcess`, 'mailsync-process');
// The Database
lazyLoad(`Matcher`, 'flux/attributes/matcher');
lazyLoad(`DatabaseStore`, 'flux/stores/database-store');
lazyLoad(`QueryResultSet`, 'flux/models/query-result-set');
lazyLoad(`QuerySubscription`, 'flux/models/query-subscription');
lazyLoad(`CalendarDataSource`, 'components/nylas-calendar/calendar-data-source');
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
lazyLoadAndRegisterModel(`ProviderSyncbackRequest`, 'provider-syncback-request');

// Search Query Interfaces
lazyLoad(`SearchQueryAST`, 'services/search/search-query-ast');
lazyLoad(`SearchQueryParser`, 'services/search/search-query-parser');
lazyLoad(`IMAPSearchQueryBackend`, 'services/search/search-query-backend-imap');

// Tasks
lazyLoad(`TaskFactory`, 'flux/tasks/task-factory');
lazyLoadAndRegisterTask(`Task`, 'task');
lazyLoadAndRegisterTask(`EventRSVPTask`, 'event-rsvp-task');
lazyLoadAndRegisterTask(`SendDraftTask`, 'send-draft-task');
lazyLoadAndRegisterTask(`ChangeMailTask`, 'change-mail-task');
lazyLoadAndRegisterTask(`DestroyDraftTask`, 'destroy-draft-task');
lazyLoadAndRegisterTask(`ChangeLabelsTask`, 'change-labels-task');
lazyLoadAndRegisterTask(`ChangeFolderTask`, 'change-folder-task');
lazyLoadAndRegisterTask(`ChangeUnreadTask`, 'change-unread-task');
lazyLoadAndRegisterTask(`DestroyModelTask`, 'destroy-model-task');
lazyLoadAndRegisterTask(`SyncbackDraftTask`, 'syncback-draft-task');
lazyLoadAndRegisterTask(`ChangeStarredTask`, 'change-starred-task');
lazyLoadAndRegisterTask(`SyncbackEventTask`, 'syncback-event-task');
lazyLoadAndRegisterTask(`DestroyCategoryTask`, 'destroy-category-task');
lazyLoadAndRegisterTask(`SyncbackCategoryTask`, 'syncback-category-task');
lazyLoadAndRegisterTask(`SyncbackMetadataTask`, 'syncback-metadata-task');
lazyLoadAndRegisterTask(`ReprocessMailRulesTask`, 'reprocess-mail-rules-task');
lazyLoadAndRegisterTask(`SendFeatureUsageEventTask`, 'send-feature-usage-event-task');

// Stores
// These need to be required immediately since some Stores are
// listen-only and not explicitly required from anywhere. Stores
// currently set themselves up on require.
load(`TaskQueue`, 'flux/stores/task-queue');
load(`BadgeStore`, 'flux/stores/badge-store');
load(`DraftStore`, 'flux/stores/draft-store');
load(`ModalStore`, 'flux/stores/modal-store');
load(`OutboxStore`, 'flux/stores/outbox-store');
load(`PopoverStore`, 'flux/stores/popover-store');
load(`AccountStore`, 'flux/stores/account-store');
load(`SignatureStore`, 'flux/stores/signature-store');
load(`MessageStore`, 'flux/stores/message-store');
load(`ContactStore`, 'flux/stores/contact-store');
load(`IdentityStore`, 'flux/stores/identity-store');
load(`CategoryStore`, 'flux/stores/category-store');
load(`UndoRedoStore`, 'flux/stores/undo-redo-store');
load(`WorkspaceStore`, 'flux/stores/workspace-store');
load(`MailRulesStore`, 'flux/stores/mail-rules-store');
load(`SendActionsStore`, 'flux/stores/send-actions-store');
load(`FeatureUsageStore`, 'flux/stores/feature-usage-store');
load(`ThreadCountsStore`, 'flux/stores/thread-counts-store');
load(`AttachmentStore`, 'flux/stores/attachment-store');
load(`OnlineStatusStore`, 'flux/stores/online-status-store');
load(`UpdateChannelStore`, 'flux/stores/update-channel-store');
load(`PreferencesUIStore`, 'flux/stores/preferences-ui-store');
load(`FocusedContentStore`, 'flux/stores/focused-content-store');
load(`MessageBodyProcessor`, 'flux/stores/message-body-processor');
load(`FocusedContactsStore`, 'flux/stores/focused-contacts-store');
load(`FolderSyncProgressStore`, 'flux/stores/folder-sync-progress-store');
load(`FocusedPerspectiveStore`, 'flux/stores/focused-perspective-store');
load(`SearchableComponentStore`, 'flux/stores/searchable-component-store');
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
lazyLoadWithGetter(`ReactDOM`, () => require('react-dom'));
lazyLoadWithGetter(`ReactTestUtils`, () => require('react-dom/test-utils'));

// React Components
lazyLoad(`ComponentRegistry`, 'registries/component-registry');

// Utils
lazyLoad(`Utils`, 'flux/models/utils');
lazyLoad(`DOMUtils`, 'dom-utils');
lazyLoad(`DateUtils`, 'date-utils');
lazyLoad(`FsUtils`, 'fs-utils');
lazyLoad(`CanvasUtils`, 'canvas-utils');
lazyLoad(`RegExpUtils`, 'regexp-utils');
lazyLoad(`MenuHelpers`, 'menu-helpers');
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
lazyLoad(`NativeNotifications`, 'native-notifications');
lazyLoad(`SanitizeTransformer`, 'services/sanitize-transformer');
lazyLoad(`QuotedHTMLTransformer`, 'services/quoted-html-transformer');
lazyLoad(`InlineStyleTransformer`, 'services/inline-style-transformer');
lazyLoad(`SearchableComponentMaker`, 'searchable-components/searchable-component-maker');
lazyLoad(`BatteryStatusManager`, 'services/battery-status-manager');

// Errors
lazyLoadWithGetter(`APIError`, () => require('../flux/errors').APIError);

// Process Internals
lazyLoad(`DefaultClientHelper`, 'default-client-helper');
lazyLoad(`SystemStartService`, 'system-start-service');

// Testing
lazyLoadWithGetter(`NylasTestUtils`, () => require('../../spec/nylas-test-utils'));

process.nextTick(() => {
  let c = 0;
  for (const key of _resolveNow) {
    c += exports[key] ? 1 : 0
  }
  return c;
});
