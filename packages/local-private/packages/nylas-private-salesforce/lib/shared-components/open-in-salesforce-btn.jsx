import React from 'react'
import {shell} from 'electron'
import {RetinaImg} from 'nylas-component-kit'
import SalesforceEnv from '../salesforce-env'

export default function OpenInSalesforceBtn({objectId, size = "small"}) {
  const openLink = (event) => {
    event.stopPropagation()
    event.preventDefault()
    shell.openExternal(`${SalesforceEnv.instanceUrl()}/${objectId}`)
  }

  return (
    <div
      className={`open-in-salesforce-btn action-icon ${size}`}
      onClick={openLink}
      title="Open in Salesforce.com"
    >
      <RetinaImg
        mode={RetinaImg.Mode.ContentPreserve}
        url={`nylas://nylas-private-salesforce/static/images/ic-salesforce-cloud-btn-${size}@2x.png`}
      />
    </div>
  )
}
OpenInSalesforceBtn.propTypes = {
  objectId: React.PropTypes.string,
  size: React.PropTypes.string,
}
