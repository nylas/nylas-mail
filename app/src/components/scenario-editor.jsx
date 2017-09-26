import React from 'react';
import PropTypes from 'prop-types';
import { Comparator, Template } from './scenario-editor-models';
import ScenarioEditorRow from './scenario-editor-row';

/**
The ScenarioEditor takes an array of ScenarioTemplate objects which define the
scenario value space. Each ScenarioTemplate defines a `key` and it's valid
`comparators` and `values`. The ScenarioEditor gives the user the option to
create and combine instances of different templates to create a scenario.

For example:

  Scenario Space:
   - ScenarioFactory("user-name", "The name of the user")
      + valueType: String
      + comparators: "contains", "starts with", etc.
    - SecnarioFactor("profession", "The profession of the user")
      + valueType: Enum
      + comparators: 'is'

  Scenario Value:
    [{
      'key': 'user-name'
      'comparator': 'contains'
      'value': 'Ben'
    },{
      'key': 'profession'
      'comparator': 'is'
      'value': 'Engineer'
    }]
*/

export default class ScenarioEditor extends React.Component {
  static displayName = 'ScenarioEditor';

  static propTypes = {
    instances: PropTypes.array,
    className: PropTypes.string,
    onChange: PropTypes.func,
    templates: PropTypes.array,
  };

  static Template = Template;
  static Comparator = Comparator;

  constructor(props) {
    super(props);
    this.state = {
      collapsed: true,
    };
  }

  _performChange(block) {
    const instances = JSON.parse(JSON.stringify(this.props.instances));
    block(instances);
    this.props.onChange(instances);
  }

  _onRemoveRule = idx => {
    this._performChange(instances => {
      if (instances.length > 1) {
        instances.splice(idx, 1);
      }
    });
  };

  _onInsertRule = () => {
    this._performChange(instances => {
      instances.push(this.props.templates[0].createDefaultInstance());
    });
  };

  _onChangeRowValue = (newInstance, idx) => {
    this._performChange(instances => {
      instances[idx] = newInstance;
    });
  };

  render() {
    return (
      <div className={this.props.className}>
        {(this.props.instances || []).map((instance, idx) => (
          <ScenarioEditorRow
            key={idx}
            instance={instance}
            removable={this.props.instances.length > 1}
            templates={this.props.templates}
            onRemove={() => this._onRemoveRule(idx)}
            onInsert={() => this._onInsertRule(idx)}
            onChange={updatedInstance => this._onChangeRowValue(updatedInstance, idx)}
          />
        ))}
      </div>
    );
  }
}
