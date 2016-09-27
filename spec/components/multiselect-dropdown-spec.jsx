import React from 'react'
import {
  scryRenderedDOMComponentsWithClass,
  Simulate,
} from 'react-addons-test-utils';

import MultiselectDropdown from '../../src/components/multiselect-dropdown'
import {renderIntoDocument} from '../nylas-test-utils'

const makeDropdown = (items = [], props = {}) => {
  return renderIntoDocument(<MultiselectDropdown {...props} items={items} />)
}
describe('MultiselectDropdown', function multiSelectedDropdown() {
  describe('_onItemClick', () => {
    it('calls onToggleItem function', () => {
      const onToggleItem = jasmine.createSpy('onToggleItem')
      const itemChecked = jasmine.createSpy('itemChecked')
      const itemKey = (i) => i
      const dropdown = makeDropdown(["annie@nylas.com", "anniecook@ostby.com"], {onToggleItem, itemChecked, itemKey})
      dropdown.setState({selectingItems: true})
      const item = scryRenderedDOMComponentsWithClass(dropdown, 'item')[0]
      Simulate.mouseDown(item)
      expect(onToggleItem).toHaveBeenCalled()
    })
  })
})
