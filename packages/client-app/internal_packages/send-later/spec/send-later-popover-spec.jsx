import React from 'react';
import {mount} from 'enzyme'
import SendLaterPopover from '../lib/send-later-popover';


const makePopover = (props = {}) => {
  return mount(
    <SendLaterPopover
      sendLaterDate={null}
      onSendLater={() => {}}
      onCancelSendLater={() => {}}
      {...props}
    />
  );
};

describe('SendLaterPopover', function sendLaterPopover() {
  describe('render', () => {
    it('renders cancel button if scheduled', () => {
      const onCancelSendLater = jasmine.createSpy('onCancelSendLater')
      const popover = makePopover({onCancelSendLater, sendLaterDate: 'date'})
      const button = popover.find('.btn-cancel')
      button.simulate('click')
      expect(onCancelSendLater).toHaveBeenCalled()
    });
  });
});
