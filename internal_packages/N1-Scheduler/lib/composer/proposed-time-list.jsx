import _ from 'underscore'
import moment from 'moment-timezone'
import React from 'react'
import {Utils} from 'nylas-exports'
import {RetinaImg} from 'nylas-component-kit'
import b64Imgs from './email-b64-images'
import {PLUGIN_URL} from '../scheduler-constants'

const TZ = moment.tz(Utils.timeZone).format("z");

export default class ProposedTimeList extends React.Component {
  static propTypes = {
    draft: React.PropTypes.object,
    inEmail: React.PropTypes.bool,
    proposals: React.PropTypes.array.isRequired,
  }

  static defaultProps = {
    draft: {},
    inEmail: false,
  }

  static displyName = "ProposedTimeList";

  _proposalUrl(proposalId) {
    const {clientId, accountId} = this.props.draft
    return `${PLUGIN_URL}/scheduler/${accountId}/${clientId}/${proposalId}`
  }

  _renderB64Img(name) {
    const imgStyles = {
      width: "16px",
      height: "16px",
      display: "inline-block",
      marginRight: "10px",
      backgroundRepeat: "no-repeat",
      backgroundImage: `url('${b64Imgs[name]}')`,
    }
    return <div style={imgStyles}></div>
  }

  _renderHeaderInEmail() {
    const styles = {
      fontSize: "16px",
      fontWeight: 400,
      margin: "0 10px 15px 10px",
    }
    return (
      <div>
        <h2 style={styles}>
          {this._renderB64Img("description")}
          {((this.props.draft.events || [])[0] || {}).title || this.props.draft.subject}
        </h2>
        <span style={{margin: "0 10px"}}>
          {this._renderB64Img("time")}
          Select a time to schedule instantly:
        </span>
      </div>
    )
  }

  _renderHeaderInCard() {
    return (
      <span>
        <span className="field-icon">
          <RetinaImg name="ic-eventcard-time.png"
            mode={RetinaImg.Mode.ContentPreserve}
          />
        </span>
        <span>Proposed times:</span>
      </span>
    )
  }

  _sProposalTimeList() {
    if (this.props.inEmail) {
      return {
        borderRadius: "4px",
        border: "1px solid rgba(0,0,0,0.15)",
        padding: "15px",
        margin: "10px 0",
        position: "relative",
      }
    }
    return {
      display: "block",
      position: "relative",
    }
  }

  _sProposalWrap() {
    return {

    }
  }

  _proposalsByDay() {
    return _.groupBy(this.props.proposals, (p) => {
      return moment.unix(p.start).dayOfYear()
    })
  }

  _sProposalTable() {
    return {
      width: "100%",
      textAlign: "center",
      borderSpacing: "0px",
    }
  }

  _sTD() {
    return {
      padding: "0 10px",
    }
  }

  _sTH() {
    return Object.assign({}, this._sTD(), {
      fontSize: "12px",
      color: "#333333",
      textTransform: "uppercase",
      fontWeight: 400,
    });
  }

  _sTDInner(isLast) {
    const styles = {
      borderBottom: "1px solid rgba(0,0,0,0.15)",
      borderRight: "1px solid rgba(0,0,0,0.15)",
      borderLeft: "1px solid rgba(0,0,0,0.15)",
      padding: "10px 5px",
    }
    if (isLast) {
      styles.borderRadius = "0 0 4px 4px";
    }
    return styles
  }

  _sTHInner() {
    return Object.assign({}, this._sTDInner(), {
      borderTop: "1px solid rgba(0,0,0,0.15)",
      borderRadius: "4px 4px 0 0",
    });
  }

  _renderProposalTable() {
    const byDay = this._proposalsByDay();
    let maxLen = 0;
    _.each(byDay, (ps) => {
      maxLen = Math.max(maxLen, ps.length)
    });

    const trs = []
    for (let i = -1; i < maxLen; i++) {
      const tds = []
      for (const dayNum in byDay) {
        if ({}.hasOwnProperty.call(byDay, dayNum)) {
          if (i === -1) {
            tds.push(
              <th key={dayNum} style={this._sTH()}>
                <div style={this._sTHInner()}>
                  {this._headerTextFromDay(dayNum)}
                </div>
              </th>
            )
          } else {
            const proposal = byDay[dayNum][i]
            if (proposal) {
              const isLast = (i === maxLen - 1) || !byDay[dayNum][i + 1]

              let timeText;
              if (this.props.inEmail) {
                const url = this._proposalUrl(proposal.id)
                timeText = (
                  <a href={url} style={{textDecoration: "none"}}>
                    {this._renderProposalTimeText(proposal)}
                  </a>
                )
              } else {
                timeText = this._renderProposalTimeText(proposal)
              }

              tds.push(
                <td key={proposal.id} style={this._sTD()}>
                  <div style={this._sTDInner(isLast)}>{timeText}</div>
                </td>
              )
            } else {
              tds.push(
                <td key={i + dayNum} style={this._sTD()}></td>
              )
            }
          }
        }
      }
      trs.push(
        <tr key={i}>{tds}</tr>
      )
    }

    return <table style={this._sProposalTable()}>{trs}</table>
  }

  _renderProposalTimeText(proposal) {
    const start = moment.unix(proposal.start).format("LT")
    const end = moment.unix(proposal.end).add(1, 'second').format("LT")
    const tz = <span style={{fontSize: "10px", color: "#aaa"}}>{TZ}</span>
    const timestr = `${start} — ${end}`
    return <span>{timestr}&nbsp;&nbsp;{tz}</span>
  }

  _headerTextFromDay(dayNum) {
    return moment().dayOfYear(dayNum).format("ddd, MMM D")
  }

  _sProposalsWrap() {
    const styles = {
      margin: "10px 0",
    }
    if (!this.props.inEmail) { styles.paddingLeft = "48px"; }
    return styles
  }

  render() {
    let header;

    if (this.props.inEmail) {
      header = this._renderHeaderInEmail()
    } else {
      header = this._renderHeaderInCard()
    }

    return (
      <div style={this._sProposalTimeList()}>
        {header}
        <div style={this._sProposalsWrap()}>
          {this._renderProposalTable()}
        </div>
      </div>
    )
  }
}
