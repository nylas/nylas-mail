import plugin from '../package.json'

export const PLUGIN_ID = plugin.name;
export const PLUGIN_NAME = "Mail Merge"
export const DEBUG = false
export const MAX_ROWS = 150

export const ParticipantFields = ['to', 'cc', 'bcc']
export const ContenteditableFields = ['subject', 'body']
export const LinkableFields = [...ParticipantFields, ...ContenteditableFields]

export const DataTransferTypes = {
  ColIdx: 'mail-merge:col-idx',
  ColName: 'mail-merge:col-name',
  DraftId: 'mail-merge:draft-client-id',
  DragBehavior: 'mail-merge:drag-behavior',
}

export const DragBehaviors = {
  Copy: 'copy',
  Move: 'move',
}

export const ActionNames = [
  'addColumn',
  'removeLastColumn',
  'addRow',
  'removeRow',
  'updateCell',
  'shiftSelection',
  'setSelection',
  'clearTableData',
  'loadTableData',
  'toggleWorkspace',
  'linkToDraft',
  'unlinkFromDraft',
]
