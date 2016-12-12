import {Message} from 'nylas-exports'
import {MailMergeDraftEditingSession} from '../lib/mail-merge-draft-editing-session'


const testReducers = [
  {testAction: state => ({...state, val1: 'reducer1'})},
  {testAction: state => ({...state, val2: 'reducer2'})},
]
const draftModel = new Message()
const draftSess = {
  draft() { return draftModel },
}

describe('MailMergeDraftEditingSession', function describeBlock() {
  let mailMergeSess;
  beforeEach(() => {
    mailMergeSess = new MailMergeDraftEditingSession(draftSess, testReducers)
  });

  describe('dispatch', () => {
    it('computes next state correctly based on registered reducers', () => {
      const nextState = mailMergeSess.dispatch({name: 'testAction'}, {})
      expect(nextState).toEqual({
        val1: 'reducer1',
        val2: 'reducer2',
      })
    });

    it('computes state value for key correctly when 2 reducers ', () => {
      const reducers = testReducers.concat([
        {testAction: state => ({...state, val2: 'reducer3'})},
      ])
      mailMergeSess = new MailMergeDraftEditingSession(draftSess, reducers)

      const nextState = mailMergeSess.dispatch({name: 'testAction'}, {})
      expect(nextState).toEqual({
        val1: 'reducer1',
        val2: 'reducer3',
      })
    });

    it('passes arguments correctly to reducers', () => {
      const args = ['arg1']
      const reducers = testReducers.concat([
        {testAction: (state, arg) => ({...state, val3: arg})},
      ])
      mailMergeSess = new MailMergeDraftEditingSession(draftSess, reducers)

      const nextState = mailMergeSess.dispatch({name: 'testAction', args}, {})
      expect(nextState).toEqual({
        val1: 'reducer1',
        val2: 'reducer2',
        val3: 'arg1',
      })
    });
  });

  describe('initializeState', () => {
    it('loads any saved metadata on the draft', () => {
      const savedMetadata = {
        tableDataSource: {},
        tokenDataSource: {},
      }
      const nextState = {next: 'state'}
      spyOn(draftModel, 'metadataForPluginId').andReturn(savedMetadata)
      spyOn(mailMergeSess, 'dispatch').andReturn(nextState)

      mailMergeSess.initializeState(draftModel)
      expect(mailMergeSess.dispatch.calls.length).toBe(2)
      const args1 = mailMergeSess.dispatch.calls[0].args
      const args2 = mailMergeSess.dispatch.calls[1].args

      expect(args1).toEqual([{name: 'fromJSON'}, savedMetadata])
      expect(args2).toEqual([{name: 'initialState'}, nextState])
      expect(mailMergeSess._state).toEqual(nextState)
    });

    it('does not laod saved metadata if saved metadata is incorrect', () => {
      const savedMetadata = {
        tableDataSource: {},
      }
      const nextState = {next: 'state'}
      spyOn(draftModel, 'metadataForPluginId').andReturn(savedMetadata)
      spyOn(mailMergeSess, 'dispatch').andReturn(nextState)

      mailMergeSess.initializeState(draftModel)
      expect(mailMergeSess.dispatch.calls.length).toBe(1)
      const {args} = mailMergeSess.dispatch.calls[0]

      expect(args).toEqual([{name: 'initialState'}])
      expect(mailMergeSess._state).toEqual(nextState)
    });

    it('just loads initial state if no metadata is saved on the draft', () => {
      const savedMetadata = {}
      const nextState = {next: 'state'}
      spyOn(draftModel, 'metadataForPluginId').andReturn(savedMetadata)
      spyOn(mailMergeSess, 'dispatch').andReturn(nextState)

      mailMergeSess.initializeState(draftModel)
      expect(mailMergeSess.dispatch.calls.length).toBe(1)
      const {args} = mailMergeSess.dispatch.calls[0]

      expect(args).toEqual([{name: 'initialState'}])
      expect(mailMergeSess._state).toEqual(nextState)
    });
  });
});
