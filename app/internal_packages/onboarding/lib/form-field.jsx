import React from 'react';
import PropTypes from 'prop-types';

const FormField = props => {
  const field = props.field;
  let val = props.account[field];
  if (props.field.includes('.')) {
    const [parent, key] = props.field.split('.');
    val = props.account[parent][key];
  }
  return (
    <span>
      <label htmlFor={props.field}>{props.title}:</label>
      <input
        type={props.type || 'text'}
        id={props.field}
        style={props.style}
        className={val && props.errorFieldNames.includes(props.field) ? 'error' : ''}
        disabled={props.submitting}
        spellCheck="false"
        value={val || ''}
        onKeyPress={props.onFieldKeyPress}
        onChange={props.onFieldChange}
      />
    </span>
  );
};

FormField.propTypes = {
  field: PropTypes.string,
  title: PropTypes.string,
  type: PropTypes.string,
  style: PropTypes.object,
  submitting: PropTypes.bool,
  onFieldKeyPress: PropTypes.func,
  onFieldChange: PropTypes.func,
  errorFieldNames: PropTypes.array,
  account: PropTypes.object,
};

export default FormField;
