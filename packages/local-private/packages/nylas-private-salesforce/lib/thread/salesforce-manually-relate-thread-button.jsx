import _ from 'underscore'
import React from 'react'
import ReactDOM from 'react-dom'

import {RetinaImg, KeyCommandsRegion} from 'nylas-component-kit'
import {Rx, Actions, FocusedContactsStore} from 'nylas-exports'

import SalesforceEnv from '../salesforce-env'
import SalesforceObject from '../models/salesforce-object'
import SalesforceActions from '../salesforce-actions'
import PendingSalesforceObject from '../form/pending-salesforce-object'
import ManuallyRelateSalesforceObjectTask from '../tasks/manually-relate-salesforce-object-task'
import SalesforceManuallyRelateThreadPopover from './salesforce-manually-relate-thread-popover'

export default class SalesforceManuallyRelateThreadButton extends React.Component {
  static displayName = "SalesforceManuallyRelateThreadButton"

  static containerRequired = false

  static propTypes = {
    items: React.PropTypes.array,
  }

  static defaultProps = {
    items: [],
  }

  constructor(props) {
    super(props)
    this._pendingPickerObjs = {};
    this.state = {
      isLoggedIn: SalesforceEnv.isLoggedIn(),
      focusedContact: FocusedContactsStore.focusedContact(),
    }
  }

  componentWillMount() {
    this._usubs = [
      SalesforceActions.syncbackSuccess.listen(this._onObjectCreate),
      SalesforceActions.salesforceWindowClosing.listen(this._onWinClose),
    ];

    this.disposable = Rx.Observable.combineLatest([
      Rx.Observable.fromStore(FocusedContactsStore),
      Rx.Observable.fromStore(SalesforceEnv),
    ]).subscribe(() => {
      this.setState({
        isLoggedIn: SalesforceEnv.isLoggedIn(),
        focusedContact: FocusedContactsStore.focusedContact(),
      })
    })
  }

  componentWillUnmount() {
    this._pendingPickerObjs = {};
    for (const usub of this._usubs) { usub() }
    this.disposable.dispose()
  }

  /**
   * When you create a new object with the picker, we drop a
   * PendingSalesforceObject in the picker before closing the popover and
   * unmounting the picker. If that objects ends up getting created, we
   * want to make sure we catch that and finish the intended user action
   * of manually relating the salesforce object.
   */
  _onObjectCreate = ({objectType, objectId, contextData = {}} = {}) => {
    const formId = contextData.formId
    const threadIds = this._pendingPickerObjs[formId] || []
    delete this._pendingPickerObjs[formId]
    const tasks = threadIds.map((threadId) => {
      Actions.recordUserEvent("Salesforce Manually Related", {
        existingObject: false,
        sObjectId: objectId,
        sObjectType: objectType,
        nylasObjectId: threadId,
        nylasObjectType: "Thread",
      });
      return new ManuallyRelateSalesforceObjectTask({
        sObjectId: objectId,
        sObjectType: objectType,
        nylasObjectId: threadId,
        nylasObjectType: "Thread",
      })
    })

    if (tasks.length > 0) Actions.queueTasks(tasks);
  }

  _onWinClose = ({contextData = {}, closingDueToObjectSuccess} = {}) => {
    if (!closingDueToObjectSuccess) {
      delete this._pendingPickerObjs[contextData.formId]
    }
  }

  _emails(props) {
    _.uniq(_.flatten(props.items.map((thread) => {
      return _.pluck((thread.participants || []), "email")
    })))
  }

  _openPopover = () => {
    const buttonRect = ReactDOM.findDOMNode(this.refs.button).getBoundingClientRect()
    Actions.openPopover(
      <SalesforceManuallyRelateThreadPopover
        threads={this.props.items}
        isLoggedIn={this.state.isLoggedIn}
        focusedContact={this.state.focusedContact}
        onObjectsPicked={this._onObjectsPicked}
      />,
      {
        originRect: buttonRect,
        direction: 'down',
      }
    )
    return
  }

  _onObjectsPicked = (pickerObjects = []) => {
    const tasks = []
    const threadIds = this.props.items.map(thread => thread.id)
    for (const pickerObj of pickerObjects) {
      if (pickerObj instanceof SalesforceObject) {
        for (const threadId of threadIds) {
          Actions.recordUserEvent("Salesforce Manually Related", {
            existingObject: true,
            sObjectId: pickerObj.id,
            sObjectType: pickerObj.type,
            nylasObjectId: threadId,
            nylasObjectType: "Thread",
          });
          const task = new ManuallyRelateSalesforceObjectTask({
            sObjectId: pickerObj.id,
            sObjectType: pickerObj.type,
            nylasObjectId: threadId,
            nylasObjectType: "Thread",
          })
          tasks.push(task);
        }
      } else if (pickerObj instanceof PendingSalesforceObject) {
        this._pendingPickerObjs[pickerObj.id] = threadIds
      } else {
        console.error(pickerObj)
        throw new Error("Invalid picker object type")
      }
    }

    if (tasks.length > 0) Actions.queueTasks(tasks);
  }

  _keymapHandlers() {
    return {
      "salesforce:show-relate-thread-popover": this._openPopover,
    }
  }

  _menuItems() {
    return [{
      label: "Thread",
      submenu: [{
        label: "Relate With Salesforce Objects...",
        command: "salesforce:show-relate-thread-popover",
        position: "endof=thread-actions",
      }],
    }]
  }

  render() {
    const title = "Relate thread to Salesforce objects"
    return (
      <KeyCommandsRegion
        globalHandlers={this._keymapHandlers()}
        globalMenuItems={this._menuItems()}
      >
        <button
          ref="button"
          style={{marginRight: 0}}
          title={title}
          onClick={this._openPopover}
          tabIndex={-1}
          className="btn btn-toolbar btn-salesforce"
        >
          <RetinaImg
            url="nylas://nylas-private-salesforce/static/images/ic-salesforce-cloud-btn-large@2x.png"
            mode={RetinaImg.Mode.ContentLight}
          />
        </button>
      </KeyCommandsRegion>
    )
  }
}
