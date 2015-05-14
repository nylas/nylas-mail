fs = require 'fs'
path = require 'path'
React = require ('react')
ReactTestUtils = React.addons.TestUtils
{FormItem,
 GeneratedForm,
 GeneratedFieldset} = require ('../../src/components/generated-form')

fixtureModule = 'internal_packages/salesforce'
Adapter = require path.join('../../', fixtureModule, 'lib/salesforce-schema-adapter.coffee')
fpath = path.join(fixtureModule, 'spec/fixtures/opportunity-layouts.json')
rawData = JSON.parse(fs.readFileSync(fpath, 'utf-8'))
testData = Adapter.convertFullEditLayout("opportunity", rawData)

describe "Form Builder", ->
  beforeEach ->
    for fieldset in testData.fieldsets
      for formItem in fieldset.formItems
        if formItem.type is "reference"
          formItem.type = React.createClass(render: -> <div></div>)

    @form = ReactTestUtils.renderIntoDocument(
      <GeneratedForm {...testData} onSubmit={->} onChange={->}></GeneratedForm>
    )

  it "generates a form", ->
    forms = ReactTestUtils.scryRenderedComponentsWithType(@form, GeneratedForm)
    $forms = ReactTestUtils.scryRenderedDOMComponentsWithTag(@form, "form")
    expect(forms.length).toBeGreaterThan 0
    expect($forms.length).toBeGreaterThan 0

  it "generates a fieldset", ->
    fieldsets = ReactTestUtils.scryRenderedComponentsWithType(@form, GeneratedFieldset)
    $fieldsets = ReactTestUtils.scryRenderedDOMComponentsWithTag(@form, "fieldset")
    expect(fieldsets.length).toBeGreaterThan 0
    expect($fieldsets.length).toBeGreaterThan 0

  it "generates a form item", ->
    items = ReactTestUtils.scryRenderedComponentsWithType(@form, FormItem)
    expect(items.length).toBeGreaterThan 0
