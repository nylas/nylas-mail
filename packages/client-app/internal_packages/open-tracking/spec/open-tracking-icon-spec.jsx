import React from 'react';
import ReactDOM from 'react-dom';
import {findRenderedDOMComponentWithClass} from 'react-addons-test-utils';

import {Message, NylasTestUtils} from 'nylas-exports'
import OpenTrackingIcon from '../lib/open-tracking-icon'
import {PLUGIN_ID} from '../lib/open-tracking-constants'

const {renderIntoDocument} = NylasTestUtils;

function makeIcon(thread, props = {}) {
  return renderIntoDocument(<OpenTrackingIcon {...props} thread={thread} />);
}

function find(component, className) {
  return ReactDOM.findDOMNode(findRenderedDOMComponentWithClass(component, className))
}

function addOpenMetadata(obj, openCount) {
  obj.applyPluginMetadata(PLUGIN_ID, {open_count: openCount});
}

describe('Open tracking icon', function openTrackingIcon() {
  beforeEach(() => {
    this.thread = {__messages: []};
  });


  it("shows no icon if the thread has no messages", () => {
    const icon = ReactDOM.findDOMNode(makeIcon(this.thread));
    expect(icon.children.length).toEqual(0);
  });

  it("shows no icon if the thread messages have no metadata", () => {
    this.thread.__messages.push(new Message());
    this.thread.__messages.push(new Message());
    const icon = ReactDOM.findDOMNode(makeIcon(this.thread));
    expect(icon.children.length).toEqual(0);
  });

  describe("With messages and metadata", () => {
    beforeEach(() => {
      this.messages = [new Message(), new Message(), new Message({draft: true})];
      this.thread.__messages.push(...this.messages);
    });

    it("shows no icon if metadata is malformed", () => {
      this.messages[0].applyPluginMetadata(PLUGIN_ID, {gar: "bage"});
      const icon = ReactDOM.findDOMNode(makeIcon(this.thread));
      expect(icon.children.length).toEqual(0);
    });

    it("shows an unopened icon if last non draft message has metadata and is unopened", () => {
      addOpenMetadata(this.messages[0], 1);
      addOpenMetadata(this.messages[1], 0);
      const icon = find(makeIcon(this.thread), "open-tracking-icon");
      expect(icon.children.length).toEqual(1);
      expect(icon.querySelector("img.unopened")).not.toBeNull();
      expect(icon.querySelector("img.opened")).toBeNull();
    });

    it("shows an opened icon if last non draft message with metadata is opened", () => {
      addOpenMetadata(this.messages[0], 0);
      addOpenMetadata(this.messages[1], 1);
      const icon = find(makeIcon(this.thread), "open-tracking-icon");
      expect(icon.children.length).toEqual(1);
      expect(icon.querySelector("img.unopened")).toBeNull();
      expect(icon.querySelector("img.opened")).not.toBeNull();
    });
  });
});
