import Reflux from 'reflux';

const ActionScopeWindow = 'window';
const ActionScopeGlobal = 'global';
const ActionScopeWorkWindow = 'work';

/*
Public: In the Flux {Architecture.md}, almost every user action
is translated into an Action object and fired globally. Stores in the app observe
these actions and perform business logic. This loose coupling means that your
packages can observe actions and perform additional logic, or fire actions which
the rest of the app will handle.

In Reflux, each {Action} is an independent object that acts as an event emitter.
You can listen to an Action, or invoke it as a function to fire it.

## Action Scopes

N1 is a multi-window application. The `scope` of an Action dictates
how it propogates between windows.

- **Global**: These actions can be listened to from any window and fired from any
  window. The action is sent from the originating window to all other windows via
  IPC, so they should be used with care. Firing this action from anywhere will
  cause all listeners in all windows to fire.

- **Main Window**: You can fire these actions in any window. They'll be sent
  to the main window and triggered there.

- **Window**: These actions only trigger listeners in the window they're fired in.

## Firing Actions

```coffee
Actions.queueTask(new ChangeStarredTask(thread: @_thread, starred: true))
```

## Listening for Actions

If you're using Reflux to create your own Store, you can use the `listenTo`
convenience method to listen for an Action. If you're creating your own class
that is not a Store, you can still use the `listen` method provided by Reflux:

```coffee
setup: ->
  @unlisten = Actions.onNewMailDeltas.listen(@onNewMailReceived, @)

onNewMailReceived: (data) ->
  console.log("You've got mail!", data)

teardown: ->
  @unlisten()
```

Section: General
*/
class Actions {

  /*
  Public: Fired when the Nylas API Connector receives new data from the API.

  *Scope: Global*

  Receives an {Object} of {Array}s of {Model}s, for example:

  ```json
  {
    'thread': [<Thread>, <Thread>]
    'contact': [<Contact>]
  }
  ```
  */
  static onNewMailDeltas = ActionScopeGlobal;

  static didReceiveSyncbackRequestDeltas = ActionScopeWindow;

  static downloadStateChanged = ActionScopeGlobal;

  static sendToAllWindows = ActionScopeGlobal;

  /*
  Public: Queue a {Task} object to the {TaskQueue}.

  *Scope: Work Window*
  */
  static queueTask = ActionScopeWorkWindow;

  /*
  Public: Queue multiple {Task} objects to the {TaskQueue}, which should be
  undone as a single user action.

  *Scope: Work Window*
  */
  static queueTasks = ActionScopeWorkWindow;

  static undoTaskId = ActionScopeWorkWindow;

  /*
  Public: Dequeue all {Task}s from the {TaskQueue}. Use with care.

  *Scope: Work Window*
  */
  static dequeueAllTasks = ActionScopeWorkWindow;
  static dequeueTask = ActionScopeWorkWindow;

  /*
  Public: Dequeue a {Task} matching the description provided.

  *Scope: Work Window*
  */
  static dequeueMatchingTask = ActionScopeWorkWindow;

  static longPollReceivedRawDeltas = ActionScopeWorkWindow;
  static longPollProcessedDeltas = ActionScopeWorkWindow;
  static willMakeAPIRequest = ActionScopeWorkWindow;
  static didMakeAPIRequest = ActionScopeWorkWindow;
  static checkOnlineStatus = ActionScopeWindow;


  static wakeLocalSyncWorkerForAccount = ActionScopeGlobal;

  /*
  Public: Retry the initial sync

  *Scope: Global*
  */
  static retryDeltaConnection = ActionScopeGlobal;

  /*
  Public: Open the preferences view.

  *Scope: Global*
  */
  static openPreferences = ActionScopeGlobal;

  /*
  Public: Switch to the preferences tab with the specific name

  *Scope: Global*
  */
  static switchPreferencesTab = ActionScopeGlobal;

  /*
  Public: Clear the developer console for the current window.

  *Scope: Window*
  */
  static clearDeveloperConsole = ActionScopeWindow;

  /*
  Public: Manage the Nylas identity
  */
  static logoutNylasIdentity = ActionScopeWindow;

  /*
  Public: Remove the selected account

  *Scope: Window*
  */
  static removeAccount = ActionScopeWindow;

  /*
  Public: Update the provided account

  *Scope: Window*

  ```
  Actions.updateAccount(account.id, {accountName: 'new'})
  ```
  */
  static updateAccount = ActionScopeWindow;

  /*
  Public: Re-order the provided account in the account list.

  *Scope: Window*

  ```
  Actions.reorderAccount(account.id, newIndex)
  ```
  */
  static reorderAccount = ActionScopeWindow;

  /*
  Public: Select the provided sheet in the current window. This action changes
  the top level sheet.

  *Scope: Window*

  ```
  Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
  ```
  */
  static selectRootSheet = ActionScopeWindow;

  /*
  Public: Toggle whether a particular column is visible. Call this action
  with one of the Sheet location constants:

  ```
  Actions.toggleWorkspaceLocationHidden(WorkspaceStore.Location.MessageListSidebar)
  ```
  */
  static toggleWorkspaceLocationHidden = ActionScopeWindow;

  /*
  Public: Focus the keyboard on an item in a collection. This action moves the
  `keyboard focus` element in lists and other components,  but does not change
  the focused DOM element.

  *Scope: Window*

  ```
  Actions.setCursorPosition(collection: 'thread', item: <Thread>)
  ```
  */
  static setCursorPosition = ActionScopeWindow;

  /*
  Public: Focus on an item in a collection. This action changes the selection
  in lists and other components, but does not change the focused DOM element.

  *Scope: Window*

  ```
  Actions.setFocus(collection: 'thread', item: <Thread>)
  ```
  */
  static setFocus = ActionScopeWindow;

  /*
  Public: Focus the interface on a specific {MailboxPerspective}.

  *Scope: Window*

  ```
  Actions.focusMailboxPerspective(<Category>)
  ```
  */
  static focusMailboxPerspective = ActionScopeWindow;

  /*
  Public: Focus the interface on the default mailbox perspective for the provided
  account id.

  *Scope: Window*
  */
  static focusDefaultMailboxPerspectiveForAccounts = ActionScopeWindow;

  /*
  Public: Focus the mailbox perspective for the given account id and category names

  *Scope: Window*

  ```
  Actions.ensureCategoryIsFocused(accountIds, categoryName)
  ```
  */
  static ensureCategoryIsFocused = ActionScopeWindow;

  /*
  Public: If the message with the provided id is currently beign displayed in the
  thread view, this action toggles whether it's full content or snippet is shown.

  *Scope: Window*

  ```
  message = <Message>
  Actions.toggleMessageIdExpanded(message.id)
  ```
  */
  static toggleMessageIdExpanded = ActionScopeWindow;

  /*
  Public: Toggle whether messages from trash and spam are shown in the current
  message view.
  */
  static toggleHiddenMessages = ActionScopeWindow;

  /*
  Public: This action toggles wether to collapse or expand all messages in a
  thread depending on if there are currently collapsed messages.

  *Scope: Window*

  ```
  Actions.toggleAllMessagesExpanded()
  ```
  */
  static toggleAllMessagesExpanded = ActionScopeWindow;

  /*
  Public: Print the currently selected thread.

  *Scope: Window*

  ```
  thread = <Thread>
  Actions.printThread(thread)
  ```
  */
  static printThread = ActionScopeWindow;

  /*
  Public: Display the thread in a new popout window

  *Scope: Window*

  ```
  thread = <Thread>
  Actions.popoutThread(thread)
  ```
  */
  static popoutThread = ActionScopeWindow;

  /*
  Public: Display the thread in the main window

  *Scope: Global*

  ```
  thread = <Thread>
  Actions.focusThreadMainWindow(thread)
  ```
  */
  static focusThreadMainWindow = ActionScopeGlobal;

  /*
  Public: Create a new reply to the provided threadId and messageId and populate
  it with the body provided.

  *Scope: Window*

  ```
  message = <Message>
  Actions.sendQuickReply({threadId: '123', messageId: '234'}, "Thanks Ben!")
  ```
  */
  static sendQuickReply = ActionScopeWindow;

  /*
  Public: Create a new reply to the provided threadId and messageId. Note that
  this action does not focus on the thread, so you may not be able to see the new draft
  unless you also call {::setFocus}.

  *Scope: Window*

  ```
  * Compose a reply to the last message in the thread
  Actions.composeReply({threadId: '123'})

  * Compose a reply to a specific message in the thread
  Actions.composeReply({threadId: '123', messageId: '123'})
  ```
  */
  static composeReply = ActionScopeWindow;

  /*
  Public: Create a new draft for forwarding the provided threadId and messageId. See
  {::composeReply} for parameters and behavior.

  *Scope: Window*
  */
  static composeForward = ActionScopeWindow;

  /*
  Public: Pop out the draft with the provided ID so the user can edit it in another
  window.

  *Scope: Window*

  ```
  messageId = '123'
  Actions.composePopoutDraft(messageId)
  ```
  */
  static composePopoutDraft = ActionScopeWindow;

  static focusDraft = ActionScopeWindow;

  /*
  Public: Open a new composer window for creating a new draft from scratch.

  *Scope: Window*

  ```
  Actions.composeNewBlankDraft()
  ```
  */
  static composeNewBlankDraft = ActionScopeWindow;

  /*
  Public: Open a new composer window for a new draft addressed to the given recipient

  *Scope: Window*

  ```
  Actions.composeNewDraftToRecipient(contact)
  ```
  */
  static composeNewDraftToRecipient = ActionScopeWindow;

  /*
  Public: Send the draft with the given ID. This Action is handled by the {DraftStore},
  which finalizes the {DraftChangeSet} and allows {ComposerExtension}s to display
  warnings and do post-processing. To change send behavior, you should consider using
  one of these objects rather than listening for the {sendDraft} action.

  *Scope: Window*

  ```
  Actions.sendDraft('123', action)
  ```
  */
  static sendDraft = ActionScopeWindow;
  static willPerformSendAction = ActionScopeGlobal;
  static didPerformSendAction = ActionScopeGlobal;
  static didCancelSendAction = ActionScopeGlobal;
  /*
  Public: Fired when a draft is successfully sent
  *Scope: Global*

  Recieves the clientId of the message that was sent
  */
  static draftDeliverySucceeded = ActionScopeGlobal;
  static draftDeliveryFailed = ActionScopeGlobal;

  static ensureMessageInSentSuccess = ActionScopeGlobal;

  static sendManyDrafts = ActionScopeWindow;
  static ensureDraftSynced = ActionScopeWindow;

  /*
  Public: Destroys the draft with the given ID. This Action is handled by the {DraftStore},
  and does not display any confirmation UI.

  *Scope: Window*
  */
  static destroyDraft = ActionScopeWindow;

  /*
  Public: Submits the user's response to an RSVP event.

  *Scope: Window*
  */
  static RSVPEvent = ActionScopeWindow;

  // FullContact Sidebar
  static getFullContactDetails = ActionScopeWindow;
  static focusContact = ActionScopeWindow;

  // Templates
  static insertTemplateId = ActionScopeWindow;
  static createTemplate = ActionScopeWindow;
  static showTemplates = ActionScopeWindow;

  // Account Sidebar
  static setCollapsedSidebarItem = ActionScopeWindow;

  /*
  Public: Remove a file from a draft.

  *Scope: Window*

  ```
  Actions.removeFile
    file: fileObject
    messageClientId: draftClientId
  ```
  */
  static removeFile = ActionScopeWindow;

  // File Actions
  // Some file actions only need to be processed in their current window
  static addAttachment = ActionScopeWindow;
  static selectAttachment = ActionScopeWindow;
  static removeAttachment = ActionScopeWindow;
  static insertAttachmentIntoDraft = ActionScopeWindow;

  static fetchAndOpenFile = ActionScopeWindow;
  static fetchAndSaveFile = ActionScopeWindow;
  static fetchAndSaveAllFiles = ActionScopeWindow;
  static fetchFile = ActionScopeWindow;
  static abortFetchFile = ActionScopeWindow;

  /*
  Public: Pop the current sheet off the Sheet stack maintained by the {WorkspaceStore}.
  This action has no effect if the window is currently showing a root sheet.

  *Scope: Window*
  */
  static popSheet = ActionScopeWindow;

  /*
  Public: Pop the to the root sheet currently selected.

  *Scope: Window*
  */
  static popToRootSheet = ActionScopeWindow;

  /*
  Public: Push a sheet of a specific type onto the Sheet stack maintained by the
  {WorkspaceStore}. Note that sheets have no state. To show a *specific* thread,
  you should push a Thread sheet and call `setFocus` to select the thread.

  *Scope: Window*

  ```
  WorkspaceStore.defineSheet 'Thread', {},
      list: ['MessageList', 'MessageListSidebar']

  ...

  @pushSheet(WorkspaceStore.Sheet.Thread)
  ```
  */
  static pushSheet = ActionScopeWindow;

  /*
  Public: Publish a user event to any analytics services linked to N1.
  */
  static recordUserEvent = ActionScopeWorkWindow;

  static addMailRule = ActionScopeWindow;
  static reorderMailRule = ActionScopeWindow;
  static updateMailRule = ActionScopeWindow;
  static deleteMailRule = ActionScopeWindow;
  static disableMailRule = ActionScopeWindow;

  static openPopover = ActionScopeWindow;
  static closePopover = ActionScopeWindow;

  static openModal = ActionScopeWindow;
  static closeModal = ActionScopeWindow;

  /*
  Public: Set metadata for a specified model and pluginId.

  *Scope: Window*

  Receives an {Model} or {Array} of {Model}s, a plugin id, and an Object that
  represents the metadata value.
  */
  static setMetadata = ActionScopeWindow;

  static draftParticipantsChanged = ActionScopeWindow;

  static findInThread = ActionScopeWindow;
  static nextSearchResult = ActionScopeWindow;
  static previousSearchResult = ActionScopeWindow;


  // Actions for the signature preferences and shared with the composer
  static addSignature = ActionScopeWindow;
  static removeSignature = ActionScopeWindow;
  static updateSignature = ActionScopeWindow;
  static selectSignature = ActionScopeWindow;
  static toggleAccount = ActionScopeWindow;

  static notifyPluginsChanged = ActionScopeGlobal;

  static expandInitialSyncState = ActionScopeWindow;

  static resetEmailCache = ActionScopeGlobal;

  static debugSync = ActionScopeGlobal;

  // Thread list actions
  static archiveThreads = ActionScopeWindow;
  static trashThreads = ActionScopeWindow;
  static markAsSpamThreads = ActionScopeWindow;
  static removeThreadsFromView = ActionScopeWindow;
  static moveThreadsToPerspective = ActionScopeWindow;
  static applyCategoryToThreads = ActionScopeWindow;
  static removeCategoryFromThreads = ActionScopeWindow;
  static threadListDidUpdate = ActionScopeWindow;
}


// Read the actions we declared on the dummy Actions object above
// and translate them into Reflux Actions

// This helper method exists to trick the Donna lexer so it doesn't
// try to understand what we're doing to the Actions object.
const create = (obj, name, scope) => {
  obj[name] = Reflux.createAction(name);
  obj[name].scope = scope;
  obj[name].sync = true;
};

const scopes = {
  window: [],
  global: [],
  work: [],
};

for (const name of Object.getOwnPropertyNames(Actions)) {
  if (name === 'length' || name === 'name' || name === 'arguments' || name === 'caller' || name === 'prototype') {
    continue;
  }
  if (Actions[name] !== 'window' && Actions[name] !== 'global' && Actions[name] !== 'work') {
    continue;
  }
  const scope = Actions[name];
  scopes[scope].push(name);
  create(Actions, name, scope);
}

Actions.windowActions = scopes.window;
Actions.workWindowActions = scopes.work;
Actions.globalActions = scopes.global;

export default Actions;
