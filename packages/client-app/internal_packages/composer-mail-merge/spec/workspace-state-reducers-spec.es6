import {
  initialState,
  toggleWorkspace,
} from '../lib/workspace-state-reducers'
import {testState} from './fixtures'


describe('WorkspaceStateReducers', function describeBlock() {
  describe('initialState', () => {
    it('always opens the workspace if there is saved data', () => {
      expect(initialState(testState)).toEqual({
        isWorkspaceOpen: true,
      })
    });

    it('defaults to closed', () => {
      expect(initialState()).toEqual({
        isWorkspaceOpen: false,
      })
    });
  });

  describe('toggleWorkspace', () => {
    it('toggles workspace worrectly', () => {
      expect(toggleWorkspace({isWorkspaceOpen: false})).toEqual({isWorkspaceOpen: true})
      expect(toggleWorkspace({isWorkspaceOpen: true})).toEqual({isWorkspaceOpen: false})
    });
  });
});
