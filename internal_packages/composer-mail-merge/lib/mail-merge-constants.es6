import plugin from '../package.json'

export const PLUGIN_ID = plugin.appId[NylasEnv.config.get("env")];
export const PLUGIN_NAME = "Mail Merge"
export const DEBUG = true

export const ParticipantFields = ['to', 'cc', 'bcc']

export const DataTransferTypes = {
  ColIdx: 'mail-merge:col-idx',
  DraftId: 'mail-merge:draft-client-id',
}

export const TableActionNames = [
  'addColumn',
  'removeColumn',
  'addRow',
  'removeRow',
  'updateCell',
  'shiftSelection',
  'setSelection',
]

export const WorkspaceActionNames = [
  'toggleWorkspace',
  'linkToDraft',
  'unlinkFromDraft',
]

export const ActionNames = [...TableActionNames, ...WorkspaceActionNames]

