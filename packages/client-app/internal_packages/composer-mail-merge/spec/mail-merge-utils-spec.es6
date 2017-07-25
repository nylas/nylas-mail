import Papa from 'papaparse'
import {
  Message,
  Contact,
  DraftHelpers,
  Actions,
  DatabaseWriter,
} from 'nylas-exports';

import {DataTransferTypes} from '../lib/mail-merge-constants'
import SendManyDraftsTask from '../lib/send-many-drafts-task'
import {
  parseCSV,
  buildDraft,
  sendManyDrafts,
  contactFromColIdx,
} from '../lib/mail-merge-utils'
import {
  testData,
  testDataSource,
  testAnchorMarkup,
  testContenteditableContent,
} from './fixtures'
import TokenDataSource from '../lib/token-data-source'


xdescribe('MailMergeUtils', function describeBlock() {
  describe('contactFromColIdx', () => {
    it('creates a contact with the correct values', () => {
      const email = 'email@email.com'
      const contact = contactFromColIdx(0, email)
      expect(contact instanceof Contact).toBe(true)
      expect(contact.email).toBe(email)
      expect(contact.name).toBe(email)
      expect(contact.clientId).toBe(`${DataTransferTypes.ColIdx}:0`)
    });
  });

  describe('buildDraft', () => {
    beforeEach(() => {
      this.baseDraft = new Message({
        draft: true,
        clientId: 'd1',
        subject: `<div>Your email is: ${testAnchorMarkup('subject-email-anchor')}`,
        body: testContenteditableContent(),
      })

      this.tokenDataSource = new TokenDataSource()
      .linkToken('to', {colName: 'email', colIdx: 1, tokenId: 'email-0'})
      .linkToken('bcc', {colName: 'email', colIdx: 1, tokenId: 'email-1'})
      .linkToken('body', {colName: 'name', colIdx: 0, tokenId: 'name-anchor'})
      .linkToken('body', {colName: 'email', colIdx: 1, tokenId: 'email-anchor'})
      .linkToken('subject', {colName: 'email', colIdx: 1, tokenId: 'subject-email-anchor'})
    });

    it('creates a draft with the correct subject based on linked columns and rowIdx', () => {
      const draft = buildDraft(this.baseDraft, {
        rowIdx: 1,
        tableDataSource: testDataSource,
        tokenDataSource: this.tokenDataSource,
      })
      expect(draft.subject).toEqual('Your email is: hilary@nylas.com')
    });

    it('creates a draft with the correct body based on linked columns and rowIdx', () => {
      const draft = buildDraft(this.baseDraft, {
        rowIdx: 1,
        tableDataSource: testDataSource,
        tokenDataSource: this.tokenDataSource,
      })
      expect(draft.body).toEqual('<div><span>hilary</span><br>stuff<span>hilary@nylas.com</span></div>')
    });

    it('creates a draft with the correct participants based on linked columns and rowIdx', () => {
      const draft = buildDraft(this.baseDraft, {
        rowIdx: 1,
        tableDataSource: testDataSource,
        tokenDataSource: this.tokenDataSource,
      })
      expect(draft.to[0].email).toEqual('hilary@nylas.com')
      expect(draft.bcc[0].email).toEqual('hilary@nylas.com')
    });

    it('throws error if value for participant field in invalid email address', () => {
      this.tokenDataSource = this.tokenDataSource.updateToken('to', 'email-0', {colName: 'name', colIdx: 0})
      expect(() => {
        buildDraft(this.baseDraft, {
          rowIdx: 1,
          tableDataSource: testDataSource,
          tokenDataSource: this.tokenDataSource,
        })
      }).toThrow()
    });
  });

  describe('sendManyDrafts', () => {
    beforeEach(() => {
      this.baseDraft = new Message({
        draft: true,
        accountId: '123',
        serverId: '111',
        clientId: 'local-111',
      })
      this.drafts = [
        new Message({draft: true, clientId: 'local-d1'}),
        new Message({draft: true, clientId: 'local-d2'}),
        new Message({draft: true, clientId: 'local-d3'}),
      ]
      this.draftSession = {
        ensureCorrectAccount: jasmine.createSpy('ensureCorrectAccount').andCallFake(() => {
          return Promise.resolve()
        }),
      }
      this.session = {
        draftSession: () => this.draftSession,
        draft: () => this.baseDraft,
      }

      spyOn(DraftHelpers, 'applyExtensionTransforms').andCallFake((d) => {
        const transformed = d.clone()
        transformed.body = 'transformed'
        return Promise.resolve(transformed)
      })
      spyOn(DatabaseWriter.prototype, 'persistModels').andReturn(Promise.resolve())
      spyOn(Actions, 'queueTask')
      spyOn(Actions, 'queueTasks')
      spyOn(NylasEnv.config, 'get').andReturn(false)
      spyOn(NylasEnv, 'close')
    })

    it('ensures account is correct', () => {
      waitsForPromise(() => {
        return sendManyDrafts(this.session, this.drafts)
        .then(() => {
          expect(this.draftSession.ensureCorrectAccount).toHaveBeenCalled()
        })
      })
    });

    it('applies extension transforms to each draft and saves them', () => {
      waitsForPromise(() => {
        return sendManyDrafts(this.session, this.drafts)
        .then(() => {
          const transformedDrafts = DatabaseWriter.prototype.persistModels.calls[0].args[0]
          expect(transformedDrafts.length).toBe(3)
          transformedDrafts.forEach((d) => {
            expect(d.body).toBe('transformed')
            expect(d.accountId).toBe('123')
            expect(d.serverId).toBe(null)
          })
        })
      })
    });

    it('queues the correct task', () => {
      waitsForPromise(() => {
        return sendManyDrafts(this.session, this.drafts)
        .then(() => {
          const task = Actions.queueTask.calls[0].args[0]
          expect(task instanceof SendManyDraftsTask).toBe(true)
          expect(task.baseDraftClientId).toBe('local-111')
          expect(task.draftIdsToSend).toEqual(['local-d1', 'local-d2', 'local-d3'])
        })
      })
    });
  });

  describe('parseCSV', () => {
    beforeEach(() => {
      spyOn(NylasEnv, 'showErrorDialog')
    });

    it('shows error when csv file is empty', () => {
      spyOn(Papa, 'parse').andCallFake((file, {complete}) => {
        complete({data: []})
      })
      waitsForPromise(() => {
        return parseCSV()
        .then((data) => {
          expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
          expect(data).toBe(null)
        })
      })
    });

    it('returns the correct table data', () => {
      spyOn(Papa, 'parse').andCallFake((file, {complete}) => {
        complete({data: [testData.columns].concat(testData.rows)})
      })
      waitsForPromise(() => {
        return parseCSV()
        .then((data) => {
          expect(data).toEqual(testData)
        })
      })
    });

    it('adds a header row if the first row contains a value that resembles an email', () => {
      spyOn(Papa, 'parse').andCallFake((file, {complete}) => {
        complete({data: [...testData.rows]})
      })
      waitsForPromise(() => {
        return parseCSV()
        .then((data) => {
          expect(data).toEqual({
            columns: ['Column 0', 'Email Address'],
            rows: testData.rows,
          })
        })
      })
    });

    it('only imports MAX_ROWS number of rows', () => {
      spyOn(Papa, 'parse').andCallFake((file, {complete}) => {
        complete({
          data: [testData.columns].concat([...testData.rows, ['extra', 'col@email.com']]),
        })
      })
      waitsForPromise(() => {
        return parseCSV(null, 2)
        .then((data) => {
          expect(data.rows.length).toBe(2)
          expect(data).toEqual(testData)
          expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
        })
      })
    });
  });
});
