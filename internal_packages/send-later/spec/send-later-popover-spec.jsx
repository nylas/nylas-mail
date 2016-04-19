import React from 'react';
import {findDOMNode} from 'react-dom';
import {Simulate, findRenderedDOMComponentWithClass} from 'react-addons-test-utils';

import {DateUtils} from 'nylas-exports'
import SendLaterPopover from '../lib/send-later-popover';
import {renderIntoDocument} from '../../../spec/nylas-test-utils'

const makePopover = (props = {})=> {
  return renderIntoDocument(
    <SendLaterPopover
      sendLaterDate={null}
      onSendLater={()=>{}}
      onCancelSendLater={()=>{}}
      {...props} />
  );
};

describe('SendLaterPopover', ()=> {
  beforeEach(()=> {
    spyOn(DateUtils, 'format').andReturn('formatted')
  });

  describe('selectDate', ()=> {
    it('calls props.onSendLtaer', ()=> {
      const onSendLater = jasmine.createSpy('onSendLater')
      const popover = makePopover({onSendLater})
      popover.selectDate({utc: ()=> 'utc'}, 'Custom')

      expect(onSendLater).toHaveBeenCalledWith('formatted', 'Custom')
    });
  });

  describe('onSelectCustomOption', ()=> {
    it('selects date', ()=> {
      const popover = makePopover()
      spyOn(popover, 'selectDate')
      popover.onSelectCustomOption('date', 'abc')
      expect(popover.selectDate).toHaveBeenCalledWith('date', 'Custom')
    });

    it('throws error if date is invalid', ()=> {
      spyOn(NylasEnv, 'showErrorDialog')
      const popover = makePopover()
      popover.onSelectCustomOption(null, 'abc')
      expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
    });
  });

  describe('render', ()=> {
    it('renders cancel button if scheduled', ()=> {
      const onCancelSendLater = jasmine.createSpy('onCancelSendLater')
      const popover = makePopover({onCancelSendLater, sendLaterDate: 'date'})
      const button = findDOMNode(
        findRenderedDOMComponentWithClass(popover, 'btn-cancel')
      )
      Simulate.click(button)
      expect(onCancelSendLater).toHaveBeenCalled()
    });
  });
});
