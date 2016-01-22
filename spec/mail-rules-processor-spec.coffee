_ = require 'underscore'
{Message,
 Contact,
 Thread,
 File,
 DatabaseStore,
 TaskQueueStatusStore,
 Actions} = require 'nylas-exports'

MailRulesProcessor = require '../src/mail-rules-processor'

Tests = [{
  rule: {
    id: "local-ac7f1671-ba03",
    name: "conditionMode Any, contains, equals",
    conditions: [
      {
        templateKey: "from"
        comparatorKey: "contains"
        value: "@nylas.com"
      },
      {
        templateKey: "from"
        comparatorKey: "equals"
        value: "oldschool@nilas.com"
      }
    ],
    conditionMode: "any",
    actions: [
      {
        templateKey: "markAsRead"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(from: [new Contact(email:'ben@nylas.com')])
    new Message(from: [new Contact(email:'ben@nylas.com.jp')])
    new Message(from: [new Contact(email:'oldschool@nilas.com')])
  ]
  bad: [
    new Message(from: [new Contact(email:'ben@other.com')])
    new Message(from: [new Contact(email:'ben@nilas.com')])
    new Message(from: [new Contact(email:'twooldschool@nilas.com')])
  ]
},{
  rule: {
    id: "local-ac7f1671-ba03",
    name: "conditionMode all, ends with, begins with",
    conditions: [
      {
        templateKey: "cc"
        comparatorKey: "endsWith"
        value: ".com"
      },
      {
        templateKey: "subject"
        comparatorKey: "beginsWith"
        value: "[TEST] "
      }
    ],
    conditionMode: "any",
    actions: [
      {
        templateKey: "applyLabel"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(cc: [new Contact(email:'ben@nylas.org')], subject: '[TEST] ABCD')
    new Message(cc: [new Contact(email:'ben@nylas.org')], subject: '[test] ABCD')
    new Message(cc: [new Contact(email:'ben@nylas.com')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@test.com')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.com')], subject: '[test] Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.org'), new Contact(email:'b@nylas.com')], subject: 'Whatever')
  ]
  bad: [
    new Message(cc: [new Contact(email:'a@hasacom.org')], subject: 'Whatever')
    new Message(cc: [new Contact(email:'a@hasacom.org')], subject: '[test]Whatever')
    new Message(cc: [new Contact(email:'a.com@hasacom.org')], subject: 'Whatever [test] ')
  ]
},{
  rule: {
    id: "local-ac7f1671-ba03",
    name: "Any attachment name endsWith, anyRecipient equals",
    conditions: [
      {
        templateKey: "anyAttachmentName"
        comparatorKey: "endsWith"
        value: ".pdf"
      },
      {
        templateKey: "anyRecipient"
        comparatorKey: "equals"
        value: "files@nylas.com"
      }
    ],
    conditionMode: "any",
    actions: [
      {
        templateKey: "changeFolder"
        value: "51a0hb8d6l78mmhy19ffx4txs"
      }
    ],
    accountId: "b5djvgcuhj6i3x8nm53d0vnjm"
  },
  good: [
    new Message(files: [new File(filename: 'bengotow.pdf')], to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'files@nylas.com')])
    new Message(to: [new Contact(email:'ben@nylas.com')], cc: [new Contact(email:'ben@test.com'), new Contact(email:'files@nylas.com')])
  ],
  bad: [
    new Message(to: [new Contact(email:'ben@nylas.org')])
    new Message(files: [new File(filename: 'bengotow.pdfz')], to: [new Contact(email:'ben@nylas.org')])
    new Message(files: [new File(filename: 'bengotowpdf')], to: [new Contact(email:'ben@nylas.org')])
    new Message(to: [new Contact(email:'afiles@nylas.com')])
    new Message(to: [new Contact(email:'files@nylas.coma')])
  ]
}]

describe "MailRulesProcessor", ->

  describe "_checkRuleForMessage", ->
    it "should correctly filter sample messages", ->
      Tests.forEach ({rule, good, bad}) =>
        for message, idx in good
          message.accountId = rule.accountId
          if MailRulesProcessor._checkRuleForMessage(rule, message) isnt true
            expect("#{idx} (#{rule.name})").toBe(true)
        for message, idx in bad
          message.accountId = rule.accountId
          if MailRulesProcessor._checkRuleForMessage(rule, message) isnt false
            expect("#{idx} (#{rule.name})").toBe(false)

    it "should check the account id", ->
      {rule, good, bad} = Tests[0]
      message = good[0]
      message.accountId = 'not the same!'
      expect(MailRulesProcessor._checkRuleForMessage(rule, message)).toBe(false)

  describe "_applyRuleToMessage", ->
    it "should queue tasks for messages", ->
      spyOn(TaskQueueStatusStore, 'waitForPerformLocal')
      spyOn(Actions, 'queueTask')
      spyOn(DatabaseStore, 'findBy').andReturn(Promise.resolve({}))
      Tests.forEach ({rule}) =>
        TaskQueueStatusStore.waitForPerformLocal.reset()
        Actions.queueTask.reset()

        message = new Message({accountId: rule.accountId})
        thread = new Thread({accountId: rule.accountId})
        response = MailRulesProcessor._applyRuleToMessage(rule, message, thread)
        expect(response instanceof Promise).toBe(true)

        waitsForPromise =>
          response.then =>
            expect(TaskQueueStatusStore.waitForPerformLocal).toHaveBeenCalled()
            expect(Actions.queueTask).toHaveBeenCalled()
