import {
  ACCOUNT_ID,
  mockImapBox,
  getTestDatabase,
} from '../helpers'
import IMAPHelpers from '../../src/local-sync-worker/imap-helpers'

describe('IMAPHelpers', function describeBlock() {
  describe('setLabelsForMessages', () => {
    beforeEach(async () => {
      this.db = await getTestDatabase()
      this.sentLabel = await this.db.Label.create({
        id: 'sent',
        accountId: ACCOUNT_ID,
        name: '\\Sent',
        role: 'sent',
      })
      this.l1 = await this.db.Label.create({
        id: 'l1',
        name: 'l1',
        accountId: ACCOUNT_ID,
      })
      this.l2 = await this.db.Label.create({
        id: 'l2',
        name: 'l2',
        accountId: ACCOUNT_ID,
      })
      this.l3 = await this.db.Label.create({
        id: 'l3',
        name: 'l3',
        accountId: ACCOUNT_ID,
      })

      this.m1 = await this.db.Message.create({
        id: 'm1',
        folderImapUID: 1,
        accountId: ACCOUNT_ID,
      })
      await this.m1.setLabels(['l1', 'l2'])
      this.m1.labels = ['l1', 'l2']

      this.m2 = await this.db.Message.create({
        id: 'm2',
        folderImapUID: 2,
        accountId: ACCOUNT_ID,
      })
      await this.m2.setLabels(['l1', 'l2'])
      this.m2.labels = ['l1', 'l2']

      this.m3 = await this.db.Message.create({
        id: 'm3',
        folderImapUID: 3,
        accountId: ACCOUNT_ID,
      })
      await this.m3.setLabels(['l1'])
      this.m3.labels = ['l1']

      this.messages = [this.m1, this.m2, this.m3]
      const messagesByUID = {
        1: this.m1,
        2: this.m2,
        3: this.m3,
      }
      this.box = mockImapBox()
      this.box.removeLabels.andCallFake(async (uids, labelsToRemove) => {
        if (!labelsToRemove || typeof labelsToRemove === 'string' || labelsToRemove.length === 0) {
          throw new Error('labelsToRemove must be a non-empty array')
        }
        for (const uid of uids) {
          const msg = messagesByUID[uid]
          msg.labels = msg.labels.filter(l => !labelsToRemove.includes(l))
        }
      })
      this.box.setLabels.andCallFake(async (uids, labelsToSet) => {
        if (!labelsToSet || typeof labelsToSet === 'string' || labelsToSet.length === 0) {
          throw new Error('labelsToSet must be a non-empty array')
        }
        for (const uid of uids) {
          const msg = messagesByUID[uid]
          msg.labels = labelsToSet
        }
      })
    })

    it('removes all labels for each message if labelIds is empty', async () => {
      const labelIds = []
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: this.messages, labelIds})
      for (const msg of this.messages) {
        expect(msg.labels.length).toBe(0)
      }
    });

    it('does not remove the sent label from messages when removing all labels', async () => {
      await this.m3.addLabel(this.sentLabel)
      this.m3.labels.push(this.sentLabel.imapLabelIdentifier())

      const labelIds = []
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: this.messages, labelIds})

      expect(this.m1.labels.length).toBe(0)
      expect(this.m2.labels.length).toBe(0)
      expect(this.m3.labels.length).toBe(1)
      expect(this.m3.labels[0]).toEqual(this.sentLabel.imapLabelIdentifier())
    });

    it('does not try to remove labels if none present', async () => {
      await this.m1.setLabels([])
      this.m1.labels = []
      await this.m3.setLabels([this.sentLabel])
      this.m3.labels = [this.sentLabel.imapLabelIdentifier()]

      const labelIds = []
      await IMAPHelpers.setLabelsForMessages({
        labelIds,
        db: this.db,
        box: this.box,
        messages: [this.m1, this.m3],
      })

      expect(this.box.removeLabels).not.toHaveBeenCalled()
      expect(this.m1.labels.length).toBe(0)
      expect(this.m3.labels.length).toBe(1)
      expect(this.m3.labels[0]).toEqual(this.sentLabel.imapLabelIdentifier())
    });

    it('sets the provided labels', async () => {
      const labelIds = ['l1', 'l3']
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: this.messages, labelIds})
      for (const msg of this.messages) {
        expect(msg.labels).toEqual = labelIds
      }
    });

    it(`keeps the sent label on messages even if it wasn't provided in the labels to set`, async () => {
      await this.m3.addLabel(this.sentLabel)
      this.m3.labels.push(this.sentLabel.imapLabelIdentifier())

      const labelIds = ['l1', 'l3']
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: this.messages, labelIds})

      expect(this.m1.labels).toEqual(labelIds)
      expect(this.m2.labels).toEqual(labelIds)
      expect(this.m3.labels).toEqual([...labelIds, this.sentLabel.imapLabelIdentifier()])
    });

    it(`does not attempt to add the sent label to messages even if the labels to set contain the sent label`, async () => {
      const labelIds = ['l1', 'l3', this.sentLabel.imapLabelIdentifier()]
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: this.messages, labelIds})
      for (const msg of this.messages) {
        expect(msg.labels).toEqual = labelIds.slice(0, 2)
      }
    })

    it(`does not attempt to set labels if no labels to set`, async () => {
      await this.m1.setLabels([])
      this.m1.labels = []
      const labelIds = [this.sentLabel.imapLabelIdentifier()]
      await IMAPHelpers.setLabelsForMessages({db: this.db, box: this.box, messages: [this.m1], labelIds})
      expect(this.box.removeLabels).not.toHaveBeenCalled()
      expect(this.m1.labels.length).toBe(0)
    })
  });
});
