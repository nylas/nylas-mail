import React from 'react';
import ReactTestUtils from 'react-addons-test-utils';

import {findDOMNode} from 'react-dom';
import {renderIntoDocument} from '../../../spec/nylas-test-utils';
import Contenteditable from '../../../src/components/contenteditable/contenteditable';
import EmojiButtonPopover from '../lib/emoji-button-popover';
import EmojiComposerExtension from '../lib/emoji-composer-extension';

describe('EmojiButtonPopover', function emojiButtonPopover() {
  beforeEach(() => {
    this.position = {
      x: 20,
      y: 40,
    }
    spyOn(EmojiButtonPopover.prototype, 'calcPosition').andReturn(this.position);
    spyOn(EmojiComposerExtension, '_onSelectEmoji').andCallThrough();

    this.component = renderIntoDocument(<EmojiButtonPopover />);
    this.canvas = findDOMNode(ReactTestUtils.findRenderedDOMComponentWithTag(this.component, 'canvas'));

    this.composer = renderIntoDocument(
      <Contenteditable
        value={''}
        onChange={jasmine.createSpy('onChange')}
        extensions={[EmojiComposerExtension]}
      />
    );
  });

  describe('when inserting emoji', () => {
    it('should insert emoji on click', () => {
      ReactTestUtils.Simulate.mouseDown(this.canvas);
      expect(EmojiComposerExtension._onSelectEmoji).toHaveBeenCalled();
    });
  });

  describe('when searching for emoji', () => {
    it('should filter for matches', () => {
      this.searchNode = findDOMNode(ReactTestUtils.findRenderedDOMComponentWithClass(this.component, 'search'))
      const event = {
        target: {
          value: "heart",
        },
      }
      ReactTestUtils.Simulate.change(this.searchNode, event);
      ReactTestUtils.Simulate.mouseDown(this.canvas);
      expect(EmojiComposerExtension._onSelectEmoji).toHaveBeenCalled();
    });
  });
});
