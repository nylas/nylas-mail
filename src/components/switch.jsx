import React from 'react';

/* Public: A small React component which renders as a horizontal on/off switch.
   Provide it with `onChange` and `checked` props just like a checkbox:

  ```
  <Switch onChange={this._onToggleChecked} checked={this.state.form.isChecked} />
  ```
*/

const Switch = (props) => {
  let classnames = "slide-switch";
  if (props.checked) {
    classnames += " active";
  }

  return (
    <div className={classnames} onClick={props.onChange}>
      <div className="handle"></div>
    </div>
  );
}

Switch.propTypes = {
  checked: React.PropTypes.bool,
  onChange: React.PropTypes.func.isRequired,
};

export default Switch;
