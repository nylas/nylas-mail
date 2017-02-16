import {Contact} from 'nylas-exports'
import {
  toDraftChanges,
  toJSON,
  initialState,
  loadTableData,
  linkToDraft,
  unlinkFromDraft,
  removeLastColumn,
  updateCell,
} from '../lib/token-state-reducers'
import {testState, testTokenDataSource, testData} from './fixtures'


describe('WorkspaceStateReducers', function describeBlock() {
  describe('toDraftChanges', () => {
    it('returns an object with participant fields populated with the correct Contact objects', () => {
      const {to, bcc} = toDraftChanges({}, testState)
      expect(to.length).toBe(1)
      expect(bcc.length).toBe(1)

      const toContact = to[0]
      const bccContact = bcc[0]
      expect(toContact instanceof Contact).toBe(true)
      expect(toContact.email).toEqual('hilary')
      expect(bccContact instanceof Contact).toEqual(true)
      expect(bccContact.email).toEqual('hilary@nylas.com')
    });
  });

  describe('toJSON', () => {
    it('only saves linked fields to json', () => {
      expect(toJSON(testState)).toEqual({
        tokenDataSource: [
          {field: 'to', colName: 'name', colIdx: 0, tokenId: 'name-0'},
          {field: 'bcc', colName: 'email', colIdx: 1, tokenId: 'email-1'},
        ],
      })
    });
  });

  describe('initialState', () => {
    it('loads saved linked fields correctly when provided', () => {
      expect(initialState({tokenDataSource: testTokenDataSource})).toEqual({
        tokenDataSource: testTokenDataSource,
      })
    });
  });

  describe('loadTableData', () => {
    describe('when newTableData contains columns that have already been linked in the prev tableData', () => {
      it(`preserves the linked fields for the old columns that are still present
         and update the index to the new value in newTableData`, () => {
        const newTableData = {
          columns: ['email', 'other'],
          rows: [
            ['donald@nylas.com', 'd'],
            ['john@gmail.com', 'j'],
          ],
        }

        const nextState = loadTableData(testState, {newTableData, prevColumns: testData.columns})
        expect(nextState.tokenDataSource.toJSON()).toEqual([
          {field: 'bcc', colName: 'email', colIdx: 0, tokenId: 'email-1'},
        ])
      });
    });

    describe('when newTableData only contains new columns', () => {
      it('unlinks all fields that are no longer present ', () => {
        const newTableData = {
          columns: ['other1'],
          rows: [
            ['donald@nylas.com'],
            ['john@gmail.com'],
          ],
        }

        const nextState = loadTableData(testState, {newTableData, prevColumns: testData.columns})
        expect(nextState.tokenDataSource.toJSON()).toEqual([])
      });
    });
  });

  describe('linkToDraft', () => {
    it('adds the new field correctly to tokenDataSource state', () => {
      const nextState = linkToDraft(testState, {
        colIdx: 1,
        colName: 'email',
        field: 'body',
        name: 'some',
        tokenId: 'email-2',
      })
      expect(nextState.tokenDataSource.toJSON()).toEqual([
        {field: 'to', colName: 'name', colIdx: 0, tokenId: 'name-0'},
        {field: 'bcc', colName: 'email', colIdx: 1, tokenId: 'email-1'},
        {field: 'body', colName: 'email', colIdx: 1, tokenId: 'email-2', name: 'some'},
      ])

      // Check that object ref is updated
      expect(testTokenDataSource).not.toBe(nextState.tokenDataSource)
    });

    it('adds a new link if column has already been linked to that field', () => {
      const nextState = linkToDraft(testState, {
        colIdx: 1,
        colName: 'email',
        field: 'bcc',
        name: 'some',
        tokenId: 'email-2',
      })
      expect(nextState.tokenDataSource.toJSON()).toEqual([
        {field: 'to', colName: 'name', colIdx: 0, tokenId: 'name-0'},
        {field: 'bcc', colName: 'email', colIdx: 1, tokenId: 'email-1'},
        {field: 'bcc', colName: 'email', colIdx: 1, tokenId: 'email-2', name: 'some'},
      ])
    });
  });

  describe('unlinkFromDraft', () => {
    it('removes field correctly from tokenDataSource state', () => {
      const nextState = unlinkFromDraft(testState, {field: 'bcc', tokenId: 'email-1'})
      expect(nextState.tokenDataSource.toJSON()).toEqual([
        {field: 'to', colName: 'name', colIdx: 0, tokenId: 'name-0'},
      ])
      // Check that object ref is updated
      expect(testTokenDataSource).not.toBe(nextState.tokenDataSource)
    });
  });

  describe('removeLastColumn', () => {
    it('removes any tokenDataSource that were associated with the removed column', () => {
      const nextState = removeLastColumn(testState)
      expect(nextState.tokenDataSource.toJSON()).toEqual([
        {field: 'to', colName: 'name', colIdx: 0, tokenId: 'name-0'},
      ])
    });
  });

  describe('updateCell', () => {
    it('updates tokenDataSource when a column name (header cell) is updated', () => {
      const nextState = updateCell(testState, {colIdx: 0, isHeader: true, value: 'nombre'})
      expect(nextState.tokenDataSource.toJSON()).toEqual([
        {field: 'to', colName: 'nombre', colIdx: 0, tokenId: 'name-0'},
        {field: 'bcc', colName: 'email', colIdx: 1, tokenId: 'email-1'},
      ])
    });

    it('does not update tokens state otherwise', () => {
      const nextState = updateCell(testState, {colIdx: 0, isHeader: false, value: 'nombre'})
      expect(nextState.tokenDataSource).toBe(testTokenDataSource)
    });
  });
});

