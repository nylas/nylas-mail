import React from 'react'
import {Popover, RetinaImg} from 'nylas-component-kit'
import SalesforceObjectPicker from '../form/salesforce-object-picker'

// TODO: Add to composer
class SalesforceComposerPicker extends React.Component {
  static displayName = "SalesforceComposerPicker"

  // Inline composers will have threadIds.
  // Popout composers will not and the threadId will be null.
  static propTypes= {
    threadId: React.PropTypes.string,
    draftClientId: React.PropTypes.string.isRequired,
  }

  static containerStyles = {
    order: 2,
  }

  _defaultObjectType() {
    return "Opportunity"
  }

  _pickerId() {
    return `${this.props.draftClientId}-Picker`
  }

  _renderPicker() {
    const button = (
      <button className="btn btn-toolbar narrow">
        <RetinaImg
          name="nylas://salesforce/static/images/salesforce-icon.png"
          style={{position: "relative", top: "-2px"}}
          mode={RetinaImg.Mode.ContentPreserve}
        />
        <RetinaImg
          name="nylas://salesforce/static/images/toolbar-chevron.png"
          style={{position: "relative", top: "-2px"}}
          mode={RetinaImg.Mode.ContentPreserve}
        />
      </button>
    )

    return (
      <Popover ref="popover" className="salesforce-composer-picker pull-right" buttonComponent={button}>
        <h2 className="picker-h2">Sync with Salesforce {this._defaultObjectType()}</h2>
        <SalesforceObjectPicker
          id={this._pickerId()}
          objectType={this._defaultObjectType()}
        />
      </Popover>
    )
  }

  render() {
    return this._renderPicker()
  }
}

export default SalesforceComposerPicker
