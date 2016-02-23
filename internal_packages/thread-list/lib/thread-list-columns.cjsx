_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'

{ListTabular,
 RetinaImg,
 MailLabel,
 MailImportantIcon,
 InjectedComponentSet} = require 'nylas-component-kit'

{Thread,
 AccountStore,
 CategoryStore,
 FocusedPerspectiveStore} = require 'nylas-exports'

{ThreadArchiveQuickAction,
 ThreadTrashQuickAction} = require './thread-list-quick-actions'

{timestamp,
 subject} = require './formatting-utils'

ThreadListParticipants = require './thread-list-participants'
ThreadListStore = require './thread-list-store'
ThreadListIcon = require './thread-list-icon'


c1 = new ListTabular.Column
  name: "★"
  resolver: (thread) =>
    [
      <ThreadListIcon key="thread-list-icon" thread={thread} />
      <MailImportantIcon
        key="mail-important-icon"
        thread={thread}
        showIfAvailableForAnyAccount={true} />
      <InjectedComponentSet
        key="injected-component-set"
        inline={true}
        containersRequired={false}
        matching={role: "ThreadListIcon"}
        className="thread-injected-icons"
        exposedProps={thread: thread}/>
    ]

c2 = new ListTabular.Column
  name: "Participants"
  width: 200
  resolver: (thread) =>
    hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
    if hasDraft
      <div style={display: 'flex'}>
        <ThreadListParticipants thread={thread} />
        <RetinaImg name="icon-draft-pencil.png"
                   className="draft-icon"
                   mode={RetinaImg.Mode.ContentPreserve} />
      </div>
    else
      <ThreadListParticipants thread={thread} />

c3LabelComponentCache = {}

c3 = new ListTabular.Column
  name: "Message"
  flex: 4
  resolver: (thread) =>
    attachment = []
    labels = []

    if thread.hasAttachments
      attachment = <div className="thread-icon thread-icon-attachment"></div>

    if AccountStore.accountForId(thread.accountId).usesLabels()
      currentCategories = FocusedPerspectiveStore.current().categories() ? []
      ignored = [].concat(currentCategories, CategoryStore.hiddenCategories(thread.accountId))
      ignoredIds = _.pluck(ignored, 'id')

      for label in (thread.sortedCategories())
        continue if label.id in ignoredIds
        c3LabelComponentCache[label.id] ?= <MailLabel label={label} key={label.id} />
        labels.push c3LabelComponentCache[label.id]

    <span className="details">
      {labels}
      <span className="subject">{subject(thread.subject)}</span>
      <span className="snippet">{thread.snippet}</span>
      {attachment}
    </span>

c4 = new ListTabular.Column
  name: "Date"
  resolver: (thread) =>
    <span className="timestamp">{timestamp(thread.lastMessageReceivedTimestamp)}</span>

c5 = new ListTabular.Column
  name: "HoverActions"
  resolver: (thread) =>
    <div className="inner">
      <InjectedComponentSet
        key="injected-component-set"
        inline={true}
        containersRequired={false}
        children=
        {[
          <ThreadTrashQuickAction key="thread-trash-quick-action" thread={thread} />
          <ThreadArchiveQuickAction key="thread-archive-quick-action" thread={thread} />
        ]}
        matching={role: "ThreadListQuickAction"}
        className="thread-injected-quick-actions"
        exposedProps={thread: thread}/>
    </div>

cNarrow = new ListTabular.Column
  name: "Item"
  flex: 1
  resolver: (thread) =>
    pencil = []
    attachment = []
    hasDraft = _.find (thread.metadata ? []), (m) -> m.draft
    if thread.hasAttachments
      attachment = <div className="thread-icon thread-icon-attachment"></div>
    if hasDraft
      pencil = <RetinaImg name="icon-draft-pencil.png" className="draft-icon" mode={RetinaImg.Mode.ContentPreserve} />

    labels = []
    if AccountStore.accountForId(thread.accountId).usesLabels()
      currentCategories = FocusedPerspectiveStore.current().categories() ? []
      ignored = [].concat(currentCategories, CategoryStore.hiddenCategories(thread.accountId))
      ignoredIds = _.pluck(ignored, 'id')

      for label in (thread.sortedCategories())
        continue if label.id in ignoredIds
        c3LabelComponentCache[label.id] ?= <MailLabel label={label} key={label.id} />
        labels.push c3LabelComponentCache[label.id]

    <div>
      <div style={display: 'flex', alignItems: 'center'}>
        <ThreadListIcon thread={thread} />
        <ThreadListParticipants thread={thread} />
        {pencil}
        <span style={flex:1}></span>
        {attachment}
        <span className="timestamp">{timestamp(thread.lastMessageReceivedTimestamp)}</span>
      </div>
      <MailImportantIcon
        thread={thread}
        showIfAvailableForAnyAccount={true} />
      <div className="subject">{subject(thread.subject)}</div>
      <div className="snippet-and-labels">
        <div className="snippet">{thread.snippet}&nbsp;</div>
        <div style={flex: 1, flexShrink: 1}></div>
        {labels}
      </div>
    </div>

module.exports =
  Narrow: [cNarrow]
  Wide: [c1, c2, c3, c4, c5]
