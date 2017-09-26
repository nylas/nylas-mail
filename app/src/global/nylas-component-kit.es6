/* eslint global-require: 0 */
/* eslint import/no-dynamic-require: 0 */

// This module exports an empty object, with a ton of defined properties that
// `require` files the first time they're called.
module.exports = exports = {};

const resolveExport = requireValue => {
  return requireValue.default || requireValue;
};

const lazyLoadWithGetter = (prop, getter) => {
  const key = `${prop}`;

  if (exports[key]) {
    throw new Error(`Fatal error: Duplicate entry in nylas-exports: ${key}`);
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
};

const lazyLoad = (prop, path) => {
  lazyLoadWithGetter(prop, () => resolveExport(require(`../components/${path}`)));
};

const lazyLoadFrom = (prop, path) => {
  lazyLoadWithGetter(prop, () => {
    const bare = require(`../components/${path}`);
    return bare[prop] ? bare[prop] : bare.default[prop];
  });
};

lazyLoad('Menu', 'menu');
lazyLoad('DropZone', 'drop-zone');
lazyLoad('Spinner', 'spinner');
lazyLoad('Switch', 'switch');
lazyLoad('FixedPopover', 'fixed-popover');
lazyLoad('DatePickerPopover', 'date-picker-popover');
lazyLoad('Modal', 'modal');
lazyLoad('Webview', 'webview');
lazyLoad('FeatureUsedUpModal', 'feature-used-up-modal');
lazyLoad('BillingModal', 'billing-modal');
lazyLoad('OpenIdentityPageButton', 'open-identity-page-button');
lazyLoad('Flexbox', 'flexbox');
lazyLoad('RetinaImg', 'retina-img');
lazyLoad('SwipeContainer', 'swipe-container');
lazyLoad('FluxContainer', 'flux-container');
lazyLoad('FocusContainer', 'focus-container');
lazyLoad('SyncingListState', 'syncing-list-state');
lazyLoad('EmptyListState', 'empty-list-state');
lazyLoad('ListTabular', 'list-tabular');
lazyLoad('Notification', 'notification');
lazyLoad('NylasCalendar', 'nylas-calendar/nylas-calendar');
lazyLoad('MiniMonthView', 'nylas-calendar/mini-month-view');
lazyLoad('CalendarEventPopover', 'nylas-calendar/calendar-event-popover');
lazyLoad('EventedIFrame', 'evented-iframe');
lazyLoad('ButtonDropdown', 'button-dropdown');
lazyLoad('Contenteditable', 'contenteditable/contenteditable');
lazyLoad('MultiselectList', 'multiselect-list');
lazyLoad('BoldedSearchResult', 'bolded-search-result');
lazyLoad('MultiselectDropdown', 'multiselect-dropdown');
lazyLoad('KeyCommandsRegion', 'key-commands-region');
lazyLoad('TabGroupRegion', 'tab-group-region');
lazyLoad('InjectedComponent', 'injected-component');
lazyLoad('TokenizingTextField', 'tokenizing-text-field');
lazyLoad('ParticipantsTextField', 'participants-text-field');
lazyLoad('MultiselectToolbar', 'multiselect-toolbar');
lazyLoad('InjectedComponentSet', 'injected-component-set');
lazyLoad('MetadataComposerToggleButton', 'metadata-composer-toggle-button');
lazyLoad('ConfigPropContainer', 'config-prop-container');
lazyLoad('DisclosureTriangle', 'disclosure-triangle');
lazyLoad('EditableList', 'editable-list');
lazyLoad('OutlineViewItem', 'outline-view-item');
lazyLoad('OutlineView', 'outline-view');
lazyLoad('DateInput', 'date-input');
lazyLoad('DatePicker', 'date-picker');
lazyLoad('TimePicker', 'time-picker');
lazyLoad('Table', 'table/table');
lazyLoadFrom('TableRow', 'table/table');
lazyLoadFrom('TableCell', 'table/table');
lazyLoad('SelectableTable', 'selectable-table');
lazyLoadFrom('SelectableTableRow', 'selectable-table');
lazyLoadFrom('SelectableTableCell', 'selectable-table');
lazyLoad('EditableTable', 'editable-table');
lazyLoadFrom('EditableTableCell', 'editable-table');
lazyLoad('Toast', 'toast');
lazyLoad('UndoToast', 'undo-toast');
lazyLoad('LazyRenderedList', 'lazy-rendered-list');
lazyLoad('OverlaidComponents', 'overlaid-components/overlaid-components');
lazyLoad('OverlaidComposerExtension', 'overlaid-components/overlaid-composer-extension');
lazyLoad('OAuthSignInPage', 'oauth-signin-page');
lazyLoadFrom('AttachmentItem', 'attachment-items');
lazyLoadFrom('ImageAttachmentItem', 'attachment-items');
lazyLoad('CodeSnippet', 'code-snippet');

lazyLoad('ScrollRegion', 'scroll-region');
lazyLoad('ResizableRegion', 'resizable-region');

lazyLoadFrom('MailLabel', 'mail-label');
lazyLoadFrom('LabelColorizer', 'mail-label');
lazyLoad('MailLabelSet', 'mail-label-set');
lazyLoad('MailImportantIcon', 'mail-important-icon');

lazyLoadFrom('FormItem', 'generated-form');
lazyLoadFrom('GeneratedForm', 'generated-form');
lazyLoadFrom('GeneratedFieldset', 'generated-form');

lazyLoad('ScenarioEditor', 'scenario-editor');
lazyLoad('NewsletterSignup', 'newsletter-signup');

lazyLoad('SearchBar', 'search-bar');

// Higher order components
lazyLoad('ListensToObservable', 'decorators/listens-to-observable');
lazyLoad('ListensToFluxStore', 'decorators/listens-to-flux-store');
lazyLoad('ListensToMovementKeys', 'decorators/listens-to-movement-keys');
lazyLoad('HasTutorialTip', 'decorators/has-tutorial-tip');
