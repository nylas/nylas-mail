/* eslint react/no-render-return-value: 0 */
import React from 'react';
import ReactDOM from 'react-dom';
import { findRenderedDOMComponentWithClass } from 'react-dom/test-utils';

import { DateUtils, Actions } from 'mailspring-exports';
import SendLaterButton from '../lib/send-later-button';
import { PLUGIN_ID } from '../lib/send-later-constants';

const node = document.createElement('div');

const makeButton = (initialState, metadataValue) => {
  const draft = {
    accountId: 'accountId',
    metadataForPluginId: () => metadataValue,
  };
  const session = {
    changes: {
      add: jasmine.createSpy('add'),
      addPluginMetadata: jasmine.createSpy('addPluginMetadata'),
    },
  };
  const button = ReactDOM.render(
    <SendLaterButton draft={draft} session={session} isValidDraft={() => true} />,
    node
  );
  if (initialState) {
    button.setState(initialState);
  }
  return button;
};

xdescribe('SendLaterButton', function sendLaterButton() {
  beforeEach(() => {
    spyOn(DateUtils, 'format').andReturn('formatted');
  });

  describe('onSendLater', () => {
    it('sets scheduled date to "saving" and adds plugin metadata to the session', () => {
      const button = makeButton(null, { sendLaterDate: 'date' });
      spyOn(button, 'setState');
      spyOn(Actions, 'finalizeDraftAndSyncbackMetadata');

      const sendLaterDate = { utc: () => 'utc' };
      button.onSendLater(sendLaterDate);
      advanceClock();

      expect(button.setState).toHaveBeenCalledWith({ saving: true });
      expect(button.props.session.changes.addPluginMetadata).toHaveBeenCalledWith(PLUGIN_ID, {
        sendLaterDate,
      });
    });

    it('displays dialog if an auth error occurs', () => {
      const button = makeButton(null, { sendLaterDate: 'date' });
      spyOn(button, 'setState');
      spyOn(AppEnv, 'reportError');
      spyOn(AppEnv, 'showErrorDialog');
      spyOn(Actions, 'finalizeDraftAndSyncbackMetadata');
      button.onSendLater({ utc: () => 'utc' });
      advanceClock();
      expect(AppEnv.reportError).toHaveBeenCalled();
      expect(AppEnv.showErrorDialog).toHaveBeenCalled();
    });

    it('closes the composer window if a sendLaterDate has been set', () => {
      const button = makeButton(null, { sendLaterDate: 'date' });
      spyOn(button, 'setState');
      spyOn(AppEnv, 'close');
      spyOn(AppEnv, 'isComposerWindow').andReturn(true);
      spyOn(Actions, 'finalizeDraftAndSyncbackMetadata');
      button.onSendLater({ utc: () => 'utc' });
      advanceClock();
      expect(AppEnv.close).toHaveBeenCalled();
    });
  });

  describe('render', () => {
    it('renders spinner if saving', () => {
      const button = ReactDOM.findDOMNode(makeButton({ saving: true }, null));
      expect(button.title).toEqual('Saving send date...');
    });

    it('renders date if message is scheduled', () => {
      spyOn(DateUtils, 'futureDateFromString').andReturn({ fromNow: () => '5 minutes' });
      const button = makeButton({ saving: false }, { sendLaterDate: 'date' });
      const span = ReactDOM.findDOMNode(findRenderedDOMComponentWithClass(button, 'at'));
      expect(span.textContent).toEqual('Sending in 5 minutes');
    });

    it('does not render date if message is not scheduled', () => {
      const button = makeButton(null, null);
      expect(() => {
        findRenderedDOMComponentWithClass(button, 'at');
      }).toThrow();
    });
  });
});
