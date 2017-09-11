import React from 'react';

const FormField = (props) => {
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
        type={props.type || "text"}
        id={props.field}
        style={props.style}
        className={(val && props.errorFieldNames.includes(props.field)) ? 'error' : ''}
        disabled={props.submitting}
        spellCheck="false"
        value={val || ''}
        onKeyPress={props.onFieldKeyPress}
        onChange={props.onFieldChange}
      />
    </span>
  );
}

FormField.propTypes = {
  field: React.PropTypes.string,
  title: React.PropTypes.string,
  type: React.PropTypes.string,
  style: React.PropTypes.object,
  submitting: React.PropTypes.bool,
  onFieldKeyPress: React.PropTypes.func,
  onFieldChange: React.PropTypes.func,
  errorFieldNames: React.PropTypes.array,
  account: React.PropTypes.object,
}

export default FormField;
