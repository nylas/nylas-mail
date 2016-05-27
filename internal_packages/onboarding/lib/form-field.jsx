import React from 'react';

const FormField = (props) => {
  return (
    <span>
      <label forHtml={props.field}>{props.title}:</label>
      <input
        type={props.type || "text"}
        id={props.field}
        style={props.style}
        className={(props.accountInfo[props.field] && props.errorFieldNames.includes(props.field)) ? 'error' : ''}
        disabled={props.submitting}
        value={props.accountInfo[props.field] || ''}
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
  accountInfo: React.PropTypes.object,
}

export default FormField;
