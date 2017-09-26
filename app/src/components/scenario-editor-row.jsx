import React from 'react';
import PropTypes from 'prop-types';
import Rx from 'rx-lite';
import { Flexbox } from 'nylas-component-kit';

import { Template } from './scenario-editor-models';

const SOURCE_SELECT_NULL = 'NULL';

class SourceSelect extends React.Component {
  static displayName = 'SourceSelect';
  static propTypes = {
    value: PropTypes.string,
    onChange: PropTypes.func.isRequired,
    options: PropTypes.oneOfType([PropTypes.object, PropTypes.array]).isRequired,
  };

  constructor(props) {
    super(props);
    this.state = {
      options: [],
    };
  }

  componentDidMount() {
    this._setupValuesSubscription();
  }

  componentWillReceiveProps(nextProps) {
    this._setupValuesSubscription(nextProps);
  }

  componentWillUnmount() {
    if (this._subscription) {
      this._subscription.dispose();
    }
    this._subscription = null;
  }

  _setupValuesSubscription(props = this.props) {
    if (this._subscription) {
      this._subscription.dispose();
    }
    this._subscription = null;
    if (props.options instanceof Rx.Observable) {
      this._subscription = props.options.subscribe(options => this.setState({ options }));
    } else {
      this.setState({ options: props.options });
    }
  }

  _onChange = event => {
    this.props.onChange({
      target: {
        value: event.target.value === SOURCE_SELECT_NULL ? null : event.target.value,
      },
    });
  };

  render() {
    // The React <select> component won't select the correct option if the value
    // is null or undefined - it just leaves the selection whatever it was in the
    // previous render. To work around this, we coerce null/undefined to SOURCE_SELECT_NULL.

    return (
      <select value={this.props.value || SOURCE_SELECT_NULL} onChange={this._onChange}>
        <option key={SOURCE_SELECT_NULL} value={SOURCE_SELECT_NULL} />
        {this.state.options.map(({ value, name }) => (
          <option key={value} value={value}>
            {name}
          </option>
        ))}
      </select>
    );
  }
}

export default class ScenarioEditorRow extends React.Component {
  static displayName = 'ScenarioEditorRow';
  static propTypes = {
    instance: PropTypes.object.isRequired,
    removable: PropTypes.bool,
    templates: PropTypes.array.isRequired,
    onChange: PropTypes.func,
    onInsert: PropTypes.func,
    onRemove: PropTypes.func,
  };

  _onChangeValue = event => {
    const instance = JSON.parse(JSON.stringify(this.props.instance));
    instance.value = event.target.value;
    this.props.onChange(instance);
  };

  _onChangeComparator = event => {
    const instance = JSON.parse(JSON.stringify(this.props.instance));
    instance.comparatorKey = event.target.value;
    this.props.onChange(instance);
  };

  _onChangeTemplate = event => {
    const instance = JSON.parse(JSON.stringify(this.props.instance));
    const newTemplate = this.props.templates.find(t => t.key === event.target.value);
    this.props.onChange(newTemplate.coerceInstance(instance));
  };

  _renderTemplateSelect() {
    const options = this.props.templates.map(({ key, name }) => (
      <option value={key} key={key}>
        {name}
      </option>
    ));
    return (
      <select value={this.props.instance.templateKey} onChange={this._onChangeTemplate}>
        {options}
      </select>
    );
  }

  _renderComparator(template) {
    const options = Object.keys(template.comparators).map(key => (
      <option key={key} value={key}>
        {template.comparators[key].name}
      </option>
    ));
    if (options.length === 0) {
      return false;
    }
    return (
      <select value={this.props.instance.comparatorKey} onChange={this._onChangeComparator}>
        {options}
      </select>
    );
  }

  _renderValue(template) {
    if (template.type === Template.Type.Enum) {
      return (
        <SourceSelect
          value={this.props.instance.value}
          onChange={this._onChangeValue}
          options={template.values}
        />
      );
    }

    if (template.type === Template.Type.String) {
      return <input type="text" value={this.props.instance.value} onChange={this._onChangeValue} />;
    }
    return false;
  }

  _renderActions() {
    return (
      <div className="actions">
        {this.props.removable && (
          <div className="btn" onClick={this.props.onRemove}>
            &minus;
          </div>
        )}
        <div className="btn" onClick={this.props.onInsert}>
          +
        </div>
      </div>
    );
  }

  render() {
    const template = this.props.templates.find(t => t.key === this.props.instance.templateKey);
    if (!template) {
      return (
        <span> Could not find template for instance key: {this.props.instance.templateKey}</span>
      );
    }
    return (
      <Flexbox direction="row" className="well-row">
        <span>
          {this._renderTemplateSelect(template)}
          {this._renderComparator(template)}
          <span>{template.valueLabel}</span>
          {this._renderValue(template)}
        </span>
        <div style={{ flex: 1 }} />
        {this._renderActions()}
      </Flexbox>
    );
  }
}
