import React from 'react'
import _ from 'underscore'
import classNames from 'classnames'
import {RetinaImg} from 'nylas-component-kit'

import SmartFields from '../form/smart-fields'
import SalesforceLoginPrompt from '../shared-components/salesforce-login-prompt'
import SalesforceObjectPicker from '../form/salesforce-object-picker'
import {CORE_RELATEABLE_OBJECT_TYPES} from '../salesforce-constants'

const PICKER_ID = "manually-relate-thread-popover"

class SalesforceManuallyRelateThreadPopover extends React.Component {
  static displayName = "SalesforceManuallyRelateThreadPopover"

  static propTypes = {
    threads: React.PropTypes.array,
    isLoggedIn: React.PropTypes.bool,
    focusedContact: React.PropTypes.object,
    onObjectsPicked: React.PropTypes.func,
  }

  static containerStyles = {
    order: 2,
    flexShrink: 0,
  }

  constructor(props) {
    super(props);
    this.state = {
      pickerValue: [],
    }
  }

  _threadIds() {
    return _.pluck(this.props.threads, "id")
  }

  _placeholder() {
    return (
      <span>
        <RetinaImg
          mode={RetinaImg.Mode.ContentPreserve}
          name="searchloupe.png"
        />
        &nbsp;&nbsp;<span>Create or search for objects</span>
      </span>
    )
  }

  _onChange = (pickerObjects = []) => {
    this.props.onObjectsPicked(pickerObjects);
    this.setState({pickerValue: []})
  }

  _renderAssociationPicker() {
    let focusedNylasContactData = null;
    let company = null
    if (this.props.focusedContact) {
      company = SmartFields.getFieldFromClearbit(this.props.focusedContact, "Contact", "Company");
    }
    if (this.props.focusedContact) {
      focusedNylasContactData = {
        id: this.props.focusedContact.id,
        name: this.props.focusedContact.name,
        email: this.props.focusedContact.email,
      }
    }
    return [
      <h5 key="relate">Relate Object to Thread</h5>,
      <SalesforceObjectPicker
        id={PICKER_ID}
        key="picker"
        ref="objectPicker"
        value={this.state.pickerValue}
        onChange={this._onChange}
        placeholder={this._placeholder()}
        referenceTo={CORE_RELATEABLE_OBJECT_TYPES}
        defaultValue={company}
        nylasObjectIds={this._threadIds()}
        nylasObjectType="Thread"
        focusedNylasContactData={focusedNylasContactData}
      />,
    ]
  }

  _renderSalesforce() {
    if (!this.props.isLoggedIn) {
      return <SalesforceLoginPrompt />
    }

    const classes = classNames({
      "salesforce": true,
      "salesforce-manually-relate-popover": true,
    })

    return (
      <div className={classes}>
        <div className="visible association-picker">
          {this._renderAssociationPicker()}
        </div>
      </div>
    )
  }

  render() {
    if (!this.props.threads) return false
    return (
      <div className="related-objects-wrap" tabIndex="-1">
        {this._renderSalesforce()}
      </div>
    )
  }
}

export default SalesforceManuallyRelateThreadPopover
