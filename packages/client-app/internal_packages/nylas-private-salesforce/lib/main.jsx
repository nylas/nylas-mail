import React from 'react'
import {Rx, ComponentRegistry, WorkspaceStore} from 'nylas-exports'

// Worker to fetch new Salesforce objects
import SalesforceDataReset from './salesforce-data-reset'
import SalesforceSyncWorker from './salesforce-sync-worker'

// Plugin-wide environment and object store
import SalesforceEnv from './salesforce-env'
import SalesforceAPIError from './salesforce-api-error'
import SalesforceErrorReporter from './salesforce-error-reporter'
import SalesforceNewMailListener from './salesforce-new-mail-listener'
// import SalesforceIntroNotification from './salesforce-intro-notification'

// Database Objects
import SalesforceSchema from './models/salesforce-schema'
import SalesforceObject from './models/salesforce-object'

// Salesforce Create / Update Forms
import SalesforceObjectForm from './form/salesforce-object-form'
import SalesforceWindowLauncher from './form/salesforce-window-launcher'

// Enhancements to Thread
import SalesforceSyncLabel from './thread/salesforce-sync-label'
import RelatedObjectsForThread from './thread/related-objects-for-thread'
import SalesforceSyncMessageStatus from './thread/salesforce-sync-message-status'
import SalesforceManuallyRelateThreadButton from './thread/salesforce-manually-relate-thread-button'

// Enhancements to Sidebar Contact info
import SalesforceContactInfo from './contact/salesforce-contact-info'

// Enhancements to Search
import SalesforceSearchIndexer from './search/salesforce-search-indexer'
import SalesforceSearchBarResults from './search/salesforce-search-bar-results'

// Enhancements to Composer
import ParticipantDecorator from './composer/participant-decorator'
import ContactSearchResults from './composer/contact-search-results'

// Tasks to sync emails back to Salesforce
import SyncSalesforceObjectsTask from './tasks/sync-salesforce-objects-task'
import DestroySalesforceObjectTask from './tasks/destroy-salesforce-object-task'
import SyncbackSalesforceObjectTask from './tasks/syncback-salesforce-object-task'
import EnsureMessageOnSalesforceTask from './tasks/ensure-message-on-salesforce-task'
import DestroyMessageOnSalesforceTask from './tasks/destroy-message-on-salesforce-task'
import UpsertOpportunityContactRoleTask from './tasks/upsert-opportunity-contact-role-task'
import ManuallyRelateSalesforceObjectTask from './tasks/manually-relate-salesforce-object-task'
import SyncThreadActivityToSalesforceTask from './tasks/sync-thread-activity-to-salesforce-task'
import RemoveManualRelationToSalesforceObjectTask from './tasks/remove-manual-relation-to-salesforce-object-task'

import SalesforceIntroNotification from './salesforce-intro-notification'
import SalesforceRelatedObjectCache from './salesforce-related-object-cache'

function SalesforceObjectFormWithWindowProps() {
  return <SalesforceObjectForm {...NylasEnv.getWindowProps()} />
}
SalesforceObjectFormWithWindowProps.containerRequired = false
SalesforceObjectFormWithWindowProps.displayName = "SalesforceObjectFormWithWindowProps"


// This special `modelConstructors` key will add the following
// constructors to the `DatabaseObjectRegistry`. This will enable model
// serialization across IPC as well as SQL Table construction.
export const modelConstructors = [
  SalesforceSchema,
  SalesforceObject,
]

// This special `taskConstructors` key will add the following
// constructors to the `TaskRegistry`. This will enable task serialization
export const taskConstructors = [
  SalesforceAPIError, // So it can go across the action bridge
  SyncSalesforceObjectsTask,
  DestroySalesforceObjectTask,
  SyncbackSalesforceObjectTask,
  EnsureMessageOnSalesforceTask,
  DestroyMessageOnSalesforceTask,
  UpsertOpportunityContactRoleTask,
  SyncThreadActivityToSalesforceTask,
  ManuallyRelateSalesforceObjectTask,
  RemoveManualRelationToSalesforceObjectTask,
]

const components = [
  {
    component: SalesforceSyncLabel,
    role: "Thread:MailLabel",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceManuallyRelateThreadButton,
    role: "ThreadActionsToolbarButton",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: RelatedObjectsForThread,
    role: "MessageListHeaders",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceSyncMessageStatus,
    role: "MessageFooterStatus",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceContactInfo,
    role: "MessageListSidebar:ContactCard",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceSearchBarResults,
    role: "SearchBarResults",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: ParticipantDecorator,
    role: "Composer:RecipientChip",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: ContactSearchResults,
    role: "ContactSearchResults",
    window: "default",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceIntroNotification,
    role: "RootSidebar:Notifications",
    window: "default",
    onlyWhenLoggedIn: false,
  },
  {
    component: ParticipantDecorator,
    role: "Composer:RecipientChip",
    window: "composer",
    onlyWhenLoggedIn: true,
  },
  {
    component: ContactSearchResults,
    role: "ContactSearchResults",
    window: "composer",
    onlyWhenLoggedIn: true,
  },
  {
    component: SalesforceObjectFormWithWindowProps,
    location: WorkspaceStore.Location.Center,
    window: "SalesforceObjectForm",
    onlyWhenLoggedIn: false,
  },
]
function setComponentActivation() {
  components.forEach((opts) => {
    if (NylasEnv.getWindowType() !== opts.window) return;
    if (opts.onlyWhenLoggedIn && !SalesforceEnv.isLoggedIn()) {
      ComponentRegistry.unregister(opts.component);
    } else {
      ComponentRegistry.register(opts.component, opts)
    }
  })
}


const stores = [
  {store: SalesforceEnv, window: "all"},
  {store: SalesforceWindowLauncher, window: "all"},
  {store: SalesforceErrorReporter, window: "default"},
  {store: SalesforceNewMailListener, window: "default"},
  {store: SalesforceRelatedObjectCache, window: "default"},
  {store: SalesforceDataReset, window: "work"},
  {store: SalesforceSyncWorker, window: "work"},
  {store: SalesforceSearchIndexer, window: "work"},
]
function storesForWindow() {
  return stores.filter(({window}) => {
    return window === NylasEnv.getWindowType() || window === "all"
  }).map(({store}) => store)
}


let disp = {dispose: () => {}}
export function activate() {
  if (NylasEnv.getWindowType() === 'SalesforceObjectForm') {
    WorkspaceStore.defineSheet(
      'Main',
      {root: true},
      {popout: ['Center']},
    )
  }
  disp = Rx.Observable.fromConfig('salesforce.id').subscribe(setComponentActivation)
  storesForWindow().forEach(s => s.activate())
}

export function deactivate() {
  disp.dispose()
  components.forEach(opts => ComponentRegistry.unregister(opts.component))
  storesForWindow().forEach(s => s.deactivate())
}
