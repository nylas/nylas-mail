import React from 'react';
import ReactDOM from 'react-dom';
import {findRenderedDOMComponentWithClass} from 'react-addons-test-utils';

import {DateUtils} from 'nylas-exports'
import SendLaterButton from '../lib/send-later-button';
import SendLaterActions from '../lib/send-later-actions';

const node = document.createElement('div');

const makeButton = (initialState, metadataValue)=> {
  const message = {
    metadataForPluginId: ()=> metadataValue,
  }
  const button = ReactDOM.render(<SendLaterButton draft={message} />, node);
  if (initialState) {
    button.setState(initialState)
  }
  return button
};

describe('SendLaterButton', ()=> {
  beforeEach(()=> {
    spyOn(DateUtils, 'format').andReturn('formatted')
    spyOn(SendLaterActions, 'sendLater')
  });

  describe('componentWillReceiveProps', ()=> {
    it('closes window if window is composer window and saving has finished', ()=> {
      makeButton({saving: true}, null)
      spyOn(NylasEnv, 'close')
      spyOn(NylasEnv, 'isComposerWindow').andReturn(true)
      makeButton(null, {sendLaterDate: 'date'})
      expect(NylasEnv.close).toHaveBeenCalled()
    });
  });

  describe('onSendLater', ()=> {
    it('sets scheduled date to "saving" and dispatches action', ()=> {
      const button = makeButton(null, {sendLaterDate: 'date'})
      spyOn(button, 'setState')
      button.onSendLater({utc: ()=> 'utc'})

      expect(SendLaterActions.sendLater).toHaveBeenCalled()
      expect(button.setState).toHaveBeenCalledWith({saving: true})
    });
  });

  describe('render', ()=> {
    it('renders spinner if saving', ()=> {
      const button = ReactDOM.findDOMNode(makeButton({saving: true}, null))
      expect(button.title).toEqual('Saving send date...')
    });

    it('renders date if message is scheduled', ()=> {
      spyOn(DateUtils, 'futureDateFromString').andReturn({fromNow: ()=> '5 minutes'})
      const button = makeButton(null, {sendLaterDate: 'date'})
      const span = ReactDOM.findDOMNode(findRenderedDOMComponentWithClass(button, 'at'))
      expect(span.textContent).toEqual('Sending in 5 minutes')
    });

    it('does not render date if message is not scheduled', ()=> {
      const button = makeButton(null, null)
      expect(()=> {
        findRenderedDOMComponentWithClass(button, 'at')
      }).toThrow()
    });
  });
});
