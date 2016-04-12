import React from 'react';
import ReactDOM from 'react-dom';
import ReactTestUtils from 'react-addons-test-utils';

import {Contact, Message} from 'nylas-exports';
import ComposerHeader from '../lib/composer-header';
import Fields from '../lib/fields';

describe("ComposerHeader", () => {
  beforeEach(() => {
    this.createWithDraft = (draft) => {
      const session = {
        changes: {
          add: jasmine.createSpy('changes.add'),
        },
      };
      this.component = ReactTestUtils.renderIntoDocument(
        <ComposerHeader
          draft={draft}
          session={session}
        />
      )
    };
    advanceClock()
  });

  describe("showAndFocusField", () => {
    beforeEach(() => {
      const draft = new Message({draft: true, accountId: TEST_ACCOUNT_ID});
      this.createWithDraft(draft);
    });

    it("should ensure the field is in enabledFields", () => {
      expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField', 'textFieldSubject'])
      this.component.showAndFocusField(Fields.Bcc);
      expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField', 'textFieldSubject', 'textFieldBcc'])
    });

    it("should ensure participantsFocused is true if necessary", () => {
      expect(this.component.state.participantsFocused).toEqual(false);
      this.component.showAndFocusField(Fields.Subject);
      expect(this.component.state.participantsFocused).toEqual(false);
      this.component.showAndFocusField(Fields.Bcc);
      expect(this.component.state.participantsFocused).toEqual(true);
    });

    it("should wait for the field to become available and then focus it", () => {
      const $el = ReactDOM.findDOMNode(this.component);
      expect($el.querySelector('.bcc-field')).toBe(null);
      this.component.showAndFocusField(Fields.Bcc);
      advanceClock();
      expect($el.querySelector('.bcc-field')).not.toBe(null);
    });
  });

  describe("hideField", () => {
    beforeEach(() => {
      const draft = new Message({draft: true, accountId: TEST_ACCOUNT_ID});
      this.createWithDraft(draft);
    });

    it("should remove the field from enabledFields", () => {
      const $el = ReactDOM.findDOMNode(this.component);

      this.component.showAndFocusField(Fields.Bcc);
      advanceClock();
      expect($el.querySelector('.bcc-field')).not.toBe(null);
      this.component.hideField(Fields.Bcc);
      advanceClock();
      expect($el.querySelector('.bcc-field')).toBe(null);
    });
  });

  describe("initial state", () => {
    it("should enable any fields that are populated", () => {
      let draft = null;

      draft = new Message({draft: true, accountId: TEST_ACCOUNT_ID});
      this.createWithDraft(draft);
      expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField', 'textFieldSubject'])

      draft = new Message({draft: true, cc: [new Contact()], bcc: [new Contact()], accountId: TEST_ACCOUNT_ID});
      this.createWithDraft(draft);
      expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'textFieldCc', 'textFieldBcc', 'fromField', 'textFieldSubject'])
    });

    describe("subject", () => {
      it("should be enabled if it is empty", () => {
        const draft = new Message({draft: true, subject: '', accountId: TEST_ACCOUNT_ID});
        this.createWithDraft(draft);
        expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField', 'textFieldSubject'])
      });

      it("should be enabled if the message is a forward", () => {
        const draft = new Message({draft: true, subject: 'Fwd: 1234', accountId: TEST_ACCOUNT_ID});
        this.createWithDraft(draft);
        expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField', 'textFieldSubject'])
      });

      it("should be hidden if the message is a reply", () => {
        const draft = new Message({draft: true, subject: 'Re: 1234', replyToMessageId: '123', accountId: TEST_ACCOUNT_ID});
        this.createWithDraft(draft);
        expect(this.component.state.enabledFields).toEqual(['textFieldTo', 'fromField'])
      });
    });
  });
});
