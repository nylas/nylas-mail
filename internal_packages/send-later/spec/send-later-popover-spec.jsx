import React, {addons} from 'react/addons';
import {Rx, DatabaseStore, DateUtils} from 'nylas-exports'
import SendLaterPopover from '../lib/send-later-popover';
import SendLaterActions from '../lib/send-later-actions';
import {renderIntoDocument} from '../../../spec/nylas-test-utils'

const {findDOMNode} = React;
const {TestUtils: {
  findRenderedDOMComponentWithClass,
}} = addons;

const makePopover = (props = {})=> {
  const popover = renderIntoDocument(<SendLaterPopover {...props} draftClientId="1" />);
  if (props.initialState) {
    popover.setState(props.initialState)
  }
  return popover
};

describe('SendLaterPopover', ()=> {
  beforeEach(()=> {
    spyOn(DatabaseStore, 'findBy')
    spyOn(Rx.Observable, 'fromQuery').andReturn(Rx.Observable.empty())
    spyOn(DateUtils, 'format').andReturn('formatted')
    spyOn(SendLaterActions, 'sendLater')
  });

  describe('onMessageChanged', ()=> {
    it('sets scheduled date correctly', ()=> {
      const popover = makePopover({initialState: {scheduledDate: 'old'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(popover, 'setState')
      spyOn(NylasEnv, 'isComposerWindow').andReturn(false)

      popover.onMessageChanged(message)

      expect(popover.setState).toHaveBeenCalledWith({scheduledDate: 'date'})
    });

    it('closes window if window is composer window and saving has finished', ()=> {
      const popover = makePopover({initialState: {scheduledDate: 'saving'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(popover, 'setState')
      spyOn(NylasEnv, 'close')
      spyOn(NylasEnv, 'isComposerWindow').andReturn(true)

      popover.onMessageChanged(message)

      expect(popover.setState).toHaveBeenCalledWith({scheduledDate: 'date'})
      expect(NylasEnv.close).toHaveBeenCalled()
    });

    it('does nothing if new date is the same as current date', ()=> {
      const popover = makePopover({initialState: {scheduledDate: 'date'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(popover, 'setState')

      popover.onMessageChanged(message)

      expect(popover.setState).not.toHaveBeenCalled()
    });
  });

  describe('selectDate', ()=> {
    it('sets scheduled date to "saving" and dispatches action', ()=> {
      const popover = makePopover()
      spyOn(popover, 'setState')
      spyOn(popover.refs.popover, 'close')
      popover.selectDate({utc: ()=> 'utc'})

      expect(SendLaterActions.sendLater).toHaveBeenCalled()
      expect(popover.setState).toHaveBeenCalledWith({scheduledDate: 'saving'})
      expect(popover.refs.popover.close).toHaveBeenCalled()
    });
  });

  describe('renderButton', ()=> {
    it('renders spinner if saving', ()=> {
      const popover = makePopover({initialState: {scheduledDate: 'saving'}})
      const button = findDOMNode(
        findRenderedDOMComponentWithClass(popover, 'btn-send-later')
      )
      expect(button.title).toEqual('Saving send date...')
    });

    it('renders date if message is scheduled', ()=> {
      spyOn(DateUtils, 'futureDateFromString').andReturn({fromNow: ()=> '5 minutes'})
      const popover = makePopover({initialState: {scheduledDate: 'date'}})
      const span = findDOMNode(findRenderedDOMComponentWithClass(popover, 'at'))
      expect(span.textContent).toEqual('Sending in 5 minutes')
    });

    it('does not render date if message is not scheduled', ()=> {
      const popover = makePopover({initialState: {scheduledDate: null}})
      expect(()=> {
        findRenderedDOMComponentWithClass(popover, 'at')
      }).toThrow()
    });
  });
});
