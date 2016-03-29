import React from 'react';
import ReactDOM from 'react-dom';

import {Message} from 'nylas-exports'
import {renderIntoDocument} from '../../../spec/nylas-test-utils'
import OpenTrackingMessageStatus from '../lib/open-tracking-message-status'
import {PLUGIN_ID} from '../lib/open-tracking-constants'

function makeIcon(message, props = {}) {
  return renderIntoDocument(<div className="temp"><OpenTrackingMessageStatus {...props} message={message} /></div>);
}

function addOpenMetadata(obj, openCount) {
  obj.applyPluginMetadata(PLUGIN_ID, {open_count: openCount});
}

describe("Open tracking message status", () => {
  beforeEach(() => {
    this.message = new Message();
  });


  it("shows nothing if the message has no metadata", () => {
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector(".read-receipt-message-status")).toBeNull();
  });


  it("shows nothing if metadata is malformed", () => {
    this.message.applyPluginMetadata(PLUGIN_ID, {gar: "bage"});
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector(".read-receipt-message-status")).toBeNull();
  });

  it("shows an unopened icon if the message has metadata and is unopened", () => {
    addOpenMetadata(this.message, 0);
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector("img.unopened")).not.toBeNull();
    expect(icon.querySelector("img.opened")).toBeNull();
  });

  it("shows an opened icon if the message has metadata and is opened", () => {
    addOpenMetadata(this.message, 1);
    const icon = ReactDOM.findDOMNode(makeIcon(this.message));
    expect(icon.querySelector("img.unopened")).toBeNull();
    expect(icon.querySelector("img.opened")).not.toBeNull();
  });
});
