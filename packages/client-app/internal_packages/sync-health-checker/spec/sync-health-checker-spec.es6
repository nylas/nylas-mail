import {ipcRenderer} from 'electron'
import SyncHealthChecker from '../lib/sync-health-checker'

const requestWithErrorResponse = () => {
  return {
    run: async () => {
      throw new Error('ECONNREFUSED');
    },
  }
}

const activityData = {account1: {time: 1490305104619, activity: ['activity']}}

const requestWithDataResponse = () => {
  return {
    run: async () => {
      return activityData
    },
  }
}

describe('SyncHealthChecker', () => {
  describe('when the worker window is not available', () => {
    beforeEach(() => {
      spyOn(SyncHealthChecker, '_buildRequest').andCallFake(requestWithErrorResponse)
      spyOn(ipcRenderer, 'send')
      spyOn(NylasEnv, 'reportError')
    })
    it('attempts to restart it', async () => {
      await SyncHealthChecker._checkSyncHealth();
      expect(NylasEnv.reportError.calls.length).toEqual(1)
      expect(ipcRenderer.send.calls[0].args[0]).toEqual('ensure-worker-window')
    })
  })
  describe('when data is returned', () => {
    beforeEach(() => {
      spyOn(SyncHealthChecker, '_buildRequest').andCallFake(requestWithDataResponse)
    })
    it('stores the data', async () => {
      await SyncHealthChecker._checkSyncHealth();
      expect(SyncHealthChecker._lastSyncActivity).toEqual(activityData)
    })
  })
})
