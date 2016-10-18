/* eslint quote-props: 0 */

import React from 'react';
import ReactTestUtils from 'react-addons-test-utils'
import {SignatureStore} from 'nylas-exports';
import SignatureComposerDropdown from '../lib/signature-composer-dropdown'
import {renderIntoDocument} from '../../../spec/nylas-test-utils'

const SIGNATURES = {
  '1': {
    id: '1',
    title: 'one',
    body: 'first test signature!',
  },
  '2': {
    id: '2',
    title: 'two',
    body: 'Here is my second sig!',
  },
}

describe('SignatureComposerDropdown', function signatureComposerDropdown() {
  beforeEach(() => {
    spyOn(SignatureStore, 'getSignatures').andReturn(SIGNATURES)
    spyOn(SignatureStore, 'selectedSignature')
    this.session = {
      changes: {
        add: jasmine.createSpy('add'),
      },
    }
    this.draft = {
      body: "draft body",
    }
    this.button = renderIntoDocument(<SignatureComposerDropdown draft={this.draft} session={this.session} />)
  })
  describe('the button dropdown', () => {
    it('calls add signature with the correct signature', () => {
      const sigToAdd = SIGNATURES['2']
      ReactTestUtils.Simulate.click(ReactTestUtils.findRenderedDOMComponentWithClass(this.button, 'only-item'))
      this.signature = ReactTestUtils.findRenderedDOMComponentWithClass(this.button, `signature-title-${sigToAdd.title}`)
      ReactTestUtils.Simulate.mouseDown(this.signature)
      expect(this.button.props.session.changes.add).toHaveBeenCalledWith({body: `${this.button.props.draft.body}<br><br><signature>${sigToAdd.body}</signature>`})
    })
    it('calls add signature with nothing when no signature is clicked and there is no current signature', () => {
      ReactTestUtils.Simulate.click(ReactTestUtils.findRenderedDOMComponentWithClass(this.button, 'only-item'))
      this.noSignature = ReactTestUtils.findRenderedDOMComponentWithClass(this.button, 'item-none')
      ReactTestUtils.Simulate.mouseDown(this.noSignature)
      expect(this.button.props.session.changes.add).toHaveBeenCalledWith({body: `${this.button.props.draft.body}<br><br><signature></signature>`})
    })
    it('finds and removes the signature when no signature is clicked and there is a current signature', () => {
      this.draft = 'draft body<signature>Remove me</signature>'
      ReactTestUtils.Simulate.click(ReactTestUtils.findRenderedDOMComponentWithClass(this.button, 'only-item'))
      this.noSignature = ReactTestUtils.findRenderedDOMComponentWithClass(this.button, 'item-none')
      ReactTestUtils.Simulate.mouseDown(this.noSignature)
      expect(this.button.props.session.changes.add).toHaveBeenCalledWith({body: `${this.button.props.draft.body}<br><br><signature></signature>`})
    })
  })
})
