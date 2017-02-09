import React from 'react';
import {mount} from 'enzyme'
import {DateUtils} from 'nylas-exports'
import {DatePickerPopover} from 'nylas-component-kit'


const makePopover = (props = {}) => {
  return mount(
    <DatePickerPopover
      dateOptions={{}}
      header={<span className="header">my header</span>}
      onSelectDate={() => {}}
      {...props}
    />
  );
};

describe('DatePickerPopover', function sendLaterPopover() {
  beforeEach(() => {
    spyOn(DateUtils, 'format').andReturn('formatted')
  });

  describe('selectDate', () => {
    it('calls props.onSelectDate', () => {
      const onSelectDate = jasmine.createSpy('onSelectDate')
      const popover = makePopover({onSelectDate})
      popover.instance().selectDate({utc: () => 'utc'}, 'Custom')

      expect(onSelectDate).toHaveBeenCalledWith('formatted', 'Custom')
    });
  });

  describe('onSelectMenuOption', () => {

  });

  describe('onCustomDateSelected', () => {
    it('selects date', () => {
      const popover = makePopover()
      const instance = popover.instance()
      spyOn(instance, 'selectDate')
      instance.onCustomDateSelected('date', 'abc')
      expect(instance.selectDate).toHaveBeenCalledWith('date', 'Custom')
    });

    it('throws error if date is invalid', () => {
      spyOn(NylasEnv, 'showErrorDialog')
      const popover = makePopover()
      popover.instance().onCustomDateSelected(null, 'abc')
      expect(NylasEnv.showErrorDialog).toHaveBeenCalled()
    });
  });

  describe('render', () => {
    it('renders the provided dateOptions', () => {
      const popover = makePopover({
        dateOptions: {
          'label 1-': () => {},
          'label 2-': () => {},
        },
      })
      const items = popover.find('.item')
      expect(items.at(0).text()).toEqual('label 1-formatted')
      expect(items.at(1).text()).toEqual('label 2-formatted')
    });

    it('renders header components', () => {
      const popover = makePopover()
      expect(popover.find('.header').text()).toEqual('my header')
    })

    it('renders footer components', () => {
      const popover = makePopover({
        footer: <span key="footer" className="footer">footer</span>,
      })
      expect(popover.find('.footer').text()).toEqual('footer')
      expect(popover.find('.date-input-section').exists()).toBe(false)
    });
  });
});

