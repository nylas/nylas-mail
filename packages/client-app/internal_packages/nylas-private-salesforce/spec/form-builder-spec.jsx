import React from 'react'
import ReactTestUtils from 'react-addons-test-utils'
import {
  FormItem,
  GeneratedForm,
  GeneratedFieldset,
} from 'nylas-component-kit'
import SalesforceSchemaAdapter from '../lib/form/salesforce-schema-adapter'
import rawData from './fixtures/opportunity-layouts.json'

const rawLayout = SalesforceSchemaAdapter.defaultLayout(rawData)
const testData = SalesforceSchemaAdapter.convertFullEditLayout({objectType: "opportunity", rawLayout: rawLayout})

function StubDiv() {
  return <div />
}

xdescribe('Form Builder', function describeBlock() {
  beforeEach(() => {
    for (let i = 0; i < testData.fieldsets.length; i++) {
      const fieldset = testData.fieldsets[i];
      for (let j = 0; j < fieldset.formItems.length; j++) {
        const formItem = fieldset.formItems[j];
        if (formItem.type === "reference") {
          formItem.type = StubDiv
        }
      }
    }
    this.form = ReactTestUtils.renderIntoDocument(
      <GeneratedForm {...testData} onSubmit={() => {}} onChange={() => {}} />
    )
  })

  it("generates a form", () => {
    const forms = ReactTestUtils.scryRenderedComponentsWithType(this.form, GeneratedForm);
    const $forms = ReactTestUtils.scryRenderedDOMComponentsWithTag(this.form, "form");
    expect(forms.length).toBeGreaterThan(0);
    expect($forms.length).toBeGreaterThan(0);
  });

  it("generates a fieldset", () => {
    const fieldsets = ReactTestUtils.scryRenderedComponentsWithType(this.form, GeneratedFieldset);
    const $fieldsets = ReactTestUtils.scryRenderedDOMComponentsWithTag(this.form, "fieldset");
    expect(fieldsets.length).toBeGreaterThan(0);
    expect($fieldsets.length).toBeGreaterThan(0);
  });

  it("generates a form item", () => {
    const items = ReactTestUtils.scryRenderedComponentsWithType(this.form, FormItem);
    expect(items.length).toBeGreaterThan(0);
  });
});
