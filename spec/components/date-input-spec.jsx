import React, {addons} from 'react/addons';
import {DateUtils} from 'nylas-exports'
import DateInput from '../../src/components/date-input';
import {renderIntoDocument} from '../nylas-test-utils'

const {findDOMNode} = React;
const {TestUtils: {
  findRenderedDOMComponentWithTag,
  findRenderedDOMComponentWithClass,
  Simulate,
}} = addons;

const makeInput = (props = {})=> {
  const input = renderIntoDocument(<DateInput {...props} dateFormat="blah" />);
  if (props.initialState) {
    input.setState(props.initialState)
  }
  return input
};

const getInputNode = (reactElement)=> {
  return findDOMNode(findRenderedDOMComponentWithTag(reactElement, 'input'))
};


describe('DateInput', ()=> {
  describe('onInputKeyDown', ()=> {
    it('should submit the input if Enter or Escape pressed', ()=> {
      const onSubmitDate = jasmine.createSpy('onSubmitDate')
      const dateInput = makeInput({onSubmitDate: onSubmitDate})
      const inputNode = getInputNode(dateInput)
      const stopPropagation = jasmine.createSpy('stopPropagation')
      const keys = ['Enter', 'Return']
      inputNode.value = 'tomorrow'
      spyOn(DateUtils, 'futureDateFromString').andReturn('someday')
      spyOn(dateInput, 'setState')

      keys.forEach((key)=> {
        Simulate.keyDown(inputNode, {key, stopPropagation})
        expect(stopPropagation).toHaveBeenCalled()
        expect(onSubmitDate).toHaveBeenCalledWith('someday', 'tomorrow')
        expect(dateInput.setState).toHaveBeenCalledWith({inputDate: null})
        stopPropagation.reset()
        onSubmitDate.reset()
        dateInput.setState.reset()
      })
    });
  });

  describe('render', ()=> {
    beforeEach(()=> {
      spyOn(DateUtils, 'format').andReturn('formatted')
    });

    it('should render a date interpretation if a date has been inputted', ()=> {
      const dateInput = makeInput({initialState: {inputDate: 'something!'}})
      spyOn(dateInput, 'setState')
      const dateInterpretation = findDOMNode(findRenderedDOMComponentWithClass(dateInput, 'date-interpretation'))

      expect(dateInterpretation.textContent).toEqual('formatted')
    });

    it('should not render a date interpretation if no input date available', ()=> {
      const dateInput = makeInput({initialState: {inputDate: null}})
      spyOn(dateInput, 'setState')
      expect(()=> {
        findRenderedDOMComponentWithClass(dateInput, 'date-interpretation')
      }).toThrow()
    });
  });
});
