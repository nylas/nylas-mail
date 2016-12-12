import React from 'react';
import SalesforceIcon from '../shared-components/salesforce-icon'
import SalesforceActions from '../salesforce-actions'
import {CORE_RELATEABLE_OBJECT_TYPES} from '../salesforce-constants'

import * as relatedHelpers from '../related-object-helpers'
import * as metadataHelpers from '../metadata-helpers'

class SalesforceSyncLabel extends React.Component {

  static displayName = 'SalesforceSyncLabel'
  static containerRequired = false

  static propTypes = {
    thread: React.PropTypes.object,
  }

  constructor(props) {
    super(props)
    this.state = this._initialState(props)
  }

  componentDidMount() {
    this._mounted = true;
    this._setupDataSource(this.props)
  }

  componentWillReceiveProps(nextProps) {
    this._setupDataSource(nextProps);
    this.setState(this._initialState(nextProps))
  }

  componentWillUnmount() {
    this._mounted = false;
    if (this.disposable && this.disposable.dispose) {
      this.disposable.dispose()
    }
  }

  _initialState(props) {
    return {
      relatedObjects: relatedHelpers.relatedSObjectsForThread(props.thread),
    }
  }

  _setupDataSource() {
    if (this.disposable && this.disposable.dispose) {
      this.disposable.dispose()
    }
    clearTimeout(this.observableTimeout)

    this.observableTimeout = setTimeout(() => {
      if (!this._mounted) return;
      this.disposable = relatedHelpers.observeRelatedSObjectsForThread(this.props.thread).subscribe((relatedObjects) => {
        this.setState({relatedObjects: relatedObjects})
      })
    }, 3000)
  }

  _requestEdit(object) {
    SalesforceActions.openObjectForm({
      objectId: object.id,
      objectType: object.type,
      objectInitialData: object,
    })
  }

  render() {
    const syncingWith = metadataHelpers.getSObjectsToSyncActivityTo(this.props.thread);
    const objs = this.state.relatedObjects
    .filter(o => CORE_RELATEABLE_OBJECT_TYPES.includes(o.type))
    .map((sObject) => {
      const syncing = syncingWith[sObject.id] ? "and syncing with " : ""
      const title = `Related to ${syncing}${sObject.type}`
      return (
        <SalesforceIcon
          key={`salesforce-label-${sObject.id}`}
          title={title}
          objectType={sObject.type}
          className={`${syncingWith[sObject.id] ? "checked" : ""}`}
        />
      )
    })
    return (
      <span style={{marginRight: 6}} className="salesforce-thread-icons">
        {objs}
      </span>
    )
  }
}

export default SalesforceSyncLabel
