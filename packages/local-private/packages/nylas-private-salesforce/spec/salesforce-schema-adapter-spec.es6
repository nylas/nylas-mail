import _ from 'underscore';
import fs from 'fs';
import path from 'path';
import {GeneratedForm, GeneratedFieldset, FormItem} from 'nylas-component-kit';

import SalesforceSchemaAdapter from '../lib/form/salesforce-schema-adapter';

const fpath = path.resolve(__dirname, 'fixtures/opportunity-layouts.json');
const opportunityLayouts = JSON.parse(fs.readFileSync(fpath, 'utf-8'));


describe("SalesforceSchemaAdapter", function describeBlock() {
  beforeEach(() => {
    const rawLayout = SalesforceSchemaAdapter.defaultLayout(opportunityLayouts);
    this.schema = SalesforceSchemaAdapter.convertFullEditLayout({objectType: "opportunity", rawLayout});
  });

  it("gets the values into the schema correctly", () => {
    expect(this.schema.id).toBeDefined();
    expect(this.schema.objectType).toBe("opportunity");

    const {fieldsets} = this.schema;
    expect(fieldsets.length).toBe(4);

    const fieldset = fieldsets[0];
    expect(fieldset.heading).toBe("Opportunity Information");
    expect(fieldset.formItems.length).toBe(14);

    const formItem = fieldset.formItems[11];
    expect(formItem.label).toBe("Amount");
    expect(formItem.type).toBe("number");
    expect(formItem.row).toBe(5);
    expect(formItem.column).toBe(1);
    expect(fieldset.formItems[0].row).toBe(0);
    expect(fieldset.formItems[0].column).toBe(0);

    const {selectOptions} = fieldset.formItems[5];
    expect(selectOptions.length).toBe(10);
    expect(selectOptions[0].value).toBe("Prospecting");
  });

  it("only uses valid form types", () => {
    const {formItems} = this.schema.fieldsets[0];
    const types = _.pluck(formItems, "type");
    const validTypes = Object.keys(FormItem.inputElementTypes);

    // Code elsewhere will custom handle these types
    const customTypes = ["reference", "textarea", "select", "EmptySpace"];

    expect(_.difference(types, validTypes.concat(customTypes))).toEqual([]);
  });

  it("generates the correct schema", () => {
    expect(_.difference(Object.keys(this.schema),
                        Object.keys(GeneratedForm.propTypes)))
          .toEqual(["schemaType", "objectType", "createdAt"]); // Leftovers not used in element

    const fieldset = this.schema.fieldsets[0];
    expect(_.difference(Object.keys(fieldset),
                        Object.keys(GeneratedFieldset.propTypes)))
          .toEqual(["rows", "columns"]); // Leftovers not used in element

    const formItem = fieldset.formItems[5];
    expect(_.difference(Object.keys(formItem),
                        Object.keys(FormItem.propTypes)))
          .toEqual(["length"]); // Leftovers not used in element
  });
});
