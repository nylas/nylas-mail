import React from 'react';
import PropTypes from 'prop-types';

/* Public: A small React component which renders as a horizontal on/off switch.
   Provide it with `onChange` and `checked` props just like a checkbox:

  ```
  <Switch onChange={this._onToggleChecked} checked={this.state.form.isChecked} />
  ```
*/

const Switch = props => {
  let classnames = `${props.className || ''} slide-switch`;
  if (props.checked) {
    classnames += ' active';
  }

  return (
    <div className={classnames} onClick={props.onChange}>
      <div className="handle" />
    </div>
  );
};

Switch.propTypes = {
  checked: PropTypes.bool,
  onChange: PropTypes.func.isRequired,
  className: PropTypes.string,
};

export default Switch;
