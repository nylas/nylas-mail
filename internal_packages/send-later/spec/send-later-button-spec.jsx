import React, {addons} from 'react/addons';
import {Rx, DatabaseStore, DateUtils, Actions} from 'nylas-exports'
import SendLaterButton from '../lib/send-later-button';
import SendLaterActions from '../lib/send-later-actions';
import {renderIntoDocument} from '../../../spec/nylas-test-utils'

const {findDOMNode} = React;
const {TestUtils: {
  findRenderedDOMComponentWithClass,
}} = addons;

const makeButton = (props = {})=> {
  const button = renderIntoDocument(<SendLaterButton {...props} draftClientId="1" />);
  if (props.initialState) {
    button.setState(props.initialState)
  }
  return button
};

describe('SendLaterButton', ()=> {
  beforeEach(()=> {
    spyOn(DatabaseStore, 'findBy')
    spyOn(Rx.Observable, 'fromQuery').andReturn(Rx.Observable.empty())
    spyOn(DateUtils, 'format').andReturn('formatted')
    spyOn(SendLaterActions, 'sendLater')
  });

  describe('onMessageChanged', ()=> {
    it('sets scheduled date correctly', ()=> {
      const button = makeButton({initialState: {scheduledDate: 'old'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(button, 'setState')
      spyOn(NylasEnv, 'isComposerWindow').andReturn(false)

      button.onMessageChanged(message)

      expect(button.setState).toHaveBeenCalledWith({scheduledDate: 'date'})
    });

    it('closes window if window is composer window and saving has finished', ()=> {
      const button = makeButton({initialState: {scheduledDate: 'saving'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(button, 'setState')
      spyOn(NylasEnv, 'close')
      spyOn(NylasEnv, 'isComposerWindow').andReturn(true)

      button.onMessageChanged(message)

      expect(button.setState).toHaveBeenCalledWith({scheduledDate: 'date'})
      expect(NylasEnv.close).toHaveBeenCalled()
    });

    it('does nothing if new date is the same as current date', ()=> {
      const button = makeButton({initialState: {scheduledDate: 'date'}})
      const message = {
        metadataForPluginId: ()=> ({sendLaterDate: 'date'}),
      }
      spyOn(button, 'setState')

      button.onMessageChanged(message)

      expect(button.setState).not.toHaveBeenCalled()
    });
  });

  describe('onSendLater', ()=> {
    it('sets scheduled date to "saving" and dispatches action', ()=> {
      const button = makeButton()
      spyOn(button, 'setState')
      spyOn(Actions, 'closePopover')
      button.onSendLater({utc: ()=> 'utc'})

      expect(SendLaterActions.sendLater).toHaveBeenCalled()
      expect(button.setState).toHaveBeenCalledWith({scheduledDate: 'saving'})
      expect(Actions.closePopover).toHaveBeenCalled()
    });
  });

  describe('render', ()=> {
    it('renders spinner if saving', ()=> {
      const button = findDOMNode(
        makeButton({initialState: {scheduledDate: 'saving'}})
      )
      expect(button.title).toEqual('Saving send date...')
    });

    it('renders date if message is scheduled', ()=> {
      spyOn(DateUtils, 'futureDateFromString').andReturn({fromNow: ()=> '5 minutes'})
      const button = makeButton({initialState: {scheduledDate: 'date'}})
      const span = findDOMNode(findRenderedDOMComponentWithClass(button, 'at'))
      expect(span.textContent).toEqual('Sending in 5 minutes')
    });

    it('does not render date if message is not scheduled', ()=> {
      const button = makeButton({initialState: {scheduledDate: null}})
      expect(()=> {
        findRenderedDOMComponentWithClass(button, 'at')
      }).toThrow()
    });
  });
});
