import React from 'react'
import {RetinaImg} from 'nylas-component-kit'

export default function SalesforceIcon(props = {}) {
  const DEFAULT_COLOR = "#8199af"
  const {objectType, className, onClick} = props
  // See https://www.lightningdesignsystem.com/icons/
  const type = objectType.toLowerCase();
  const colorMap = {
    "lead": "#f88962",
    "task": "#4bc076",
    "case": "#f2cf5b",
    "account": "#7f8de1",
    "contact": "#a094ed",
    "pending": DEFAULT_COLOR,
    "opportunity": "#fcb95b",
    "lead_convert": "#f88962",
    "emailmessage": "#95aec5",
  }
  const clickFn = onClick || (() => {});
  const color = props.pending ? DEFAULT_COLOR : (colorMap[type] || DEFAULT_COLOR);
  return (
    <span
      onClick={clickFn}
      title={props.title || ""}
      className={`sf-icon-wrap sf-icon-wrap-${type} ${className || ""}`}
      style={{backgroundColor: color}}
    >
      <RetinaImg
        className="sf-icon-img"
        mode={RetinaImg.Mode.ContentPreserve}
        url={`nylas://nylas-private-salesforce/static/images/icons/${type}_120.png`}
      />
    </span>
  )
}
SalesforceIcon.propTypes = {
  title: React.PropTypes.string,
  pending: React.PropTypes.bool,
  onClick: React.PropTypes.func,
  className: React.PropTypes.string,
  objectType: React.PropTypes.string.isRequired,
}
