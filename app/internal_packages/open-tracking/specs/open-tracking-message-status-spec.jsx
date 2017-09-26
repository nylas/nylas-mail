import React from 'react';
import ReactDOM from 'react-dom';

import { Message, MailspringTestUtils } from 'mailspring-exports';
import OpenTrackingMessageStatus from '../lib/open-tracking-message-status';
import { PLUGIN_ID } from '../lib/open-tracking-constants';

const { renderIntoDocument } = MailspringTestUtils;

function makeIcon(message, props = {}) {
  return renderIntoDocument(
    <div className="temp">
      <OpenTrackingMessageStatus {...props} message={message} />
    </div>
  );
}

function addOpenMetadata(obj, openCount) {
  obj.directlyAttachMetadata(PLUGIN_ID, { open_count: openCount });
}

describe('Open tracking message status', function openTrackingMessageStatus() {
  beforeEach(() => {
    this.message = new Message();
  });

  it('shows nothing if the message has no metadata', () => {
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector('.open-tracking-message-status')).toBeNull();
  });

  it('shows nothing if metadata is malformed', () => {
    this.message.directlyAttachMetadata(PLUGIN_ID, { gar: 'bage' });
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector('.open-tracking-message-status')).toBeNull();
  });

  it('shows an unopened icon if the message has metadata and is unopened', () => {
    addOpenMetadata(this.message, 0);
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector('img.unopened')).not.toBeNull();
    expect(icon.querySelector('img.opened')).toBeNull();
  });

  it('shows an opened icon if the message has metadata and is opened', () => {
    addOpenMetadata(this.message, 1);
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector('img.unopened')).toBeNull();
    expect(icon.querySelector('img.opened')).not.toBeNull();
  });
});
