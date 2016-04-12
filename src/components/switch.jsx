import React from 'react';

/* Public: A small React component which renders as a horizontal on/off switch.
   Provide it with `onChange` and `checked` props just like a checkbox:

  ```
  <Switch onChange={this._onToggleChecked} checked={this.state.form.isChecked} />
  ```
*/

class Switch extends React.Component {

  static propTypes = {
    checked: React.PropTypes.bool,
    onChange: React.PropTypes.func.isRequired,
  }

  constructor() {
    super();
  }

  render() {
    let classnames = "slide-switch";
    if (this.props.checked) {
      classnames += " active";
    }

    return (
      <div className={classnames} onClick={this.props.onChange}>
        <div className="handle"></div>
      </div>
    );
  }

}

export default Switch;
