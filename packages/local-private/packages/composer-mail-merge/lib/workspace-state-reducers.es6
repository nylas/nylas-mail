export function initialState(savedData) {
  if (savedData && savedData.tokenDataSource && savedData.tableDataSource) {
    return {
      isWorkspaceOpen: true,
    }
  }
  return {
    isWorkspaceOpen: false,
  }
}

export function toggleWorkspace({isWorkspaceOpen}) {
  return {isWorkspaceOpen: !isWorkspaceOpen}
}
