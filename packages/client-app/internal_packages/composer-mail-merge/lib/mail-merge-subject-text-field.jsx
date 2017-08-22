/* eslint react/no-danger: 0 */
import React, {Component, PropTypes} from 'react'
import {findDOMNode} from 'react-dom'
import {EditorAPI} from 'nylas-exports'
import {OverlaidComponents, DropZone} from 'nylas-component-kit'
import ListensToMailMergeSession from './listens-to-mail-merge-session'
import * as Handlers from './mail-merge-token-dnd-handlers'


class MailMergeSubjectTextField extends Component {
  static displayName = 'MailMergeSubjectTextField'

  static containerRequired = false

  static propTypes = {
    value: PropTypes.string,
    fallback: PropTypes.func,
    draft: PropTypes.object,
    session: PropTypes.object,
    sessionState: PropTypes.object,
    draftClientId: PropTypes.string,
    onSubjectChange: PropTypes.func.isRequired,
  }

  componentDidMount() {
    const {isWorkspaceOpen} = this.props.sessionState

    this.savedSelection = null
    if (isWorkspaceOpen) {
      this.editor = new EditorAPI(findDOMNode(this.refs.contenteditable))
    }
  }

  shouldComponentUpdate(nextProps) {
    return (
      this.props.draftClientId !== nextProps.draftClientId ||
      this.props.value !== nextProps.value ||
      this.props.sessionState.isWorkspaceOpen !== nextProps.sessionState.isWorkspaceOpen
    )
  }

  componentDidUpdate() {
    const {isWorkspaceOpen} = this.props.sessionState

    if (isWorkspaceOpen) {
      this.editor = new EditorAPI(findDOMNode(this.refs.contenteditable))
      if (this.savedSelection && this.savedSelection.rawSelection.anchorNode) {
        this.editor.select(this.savedSelection)
        this.savedSelection = null
      }
    }
  }

  onInputChange = (event) => {
    const value = event.target.innerHTML
    this.savedSelection = this.editor.currentSelection().exportSelection()
    this.props.onSubjectChange(value)
  }

  onInputKeyDown = (event) => {
    if (['Enter', 'Return'].includes(event.key)) {
      event.stopPropagation()
      event.preventDefault()
    }
  }

  onDrop = (event) => {
    Handlers.onDrop('subject', {editor: this.editor, event})
  }

  onDragOver = (event) => {
    Handlers.onDragOver({editor: this.editor, event})
  }

  shouldAcceptDrop = (event) => {
    return Handlers.shouldAcceptDrop({event})
  }

  focus() {
    const {isWorkspaceOpen} = this.props.sessionState

    if (isWorkspaceOpen) {
      findDOMNode(this.refs.contenteditable).focus()
    } else {
      this.refs.fallback.focus()
    }
  }

  renderContenteditable() {
    const {value} = this.props
    return (
      <DropZone
        className="mail-merge-subject-text-field composer-subject subject-field"
        onDrop={this.onDrop}
        onDragOver={this.onDragOver}
        shouldAcceptDrop={this.shouldAcceptDrop}
      >
        <div
          ref="contenteditable"
          contentEditable
          name="subject"
          placeholder="Subject"
          onBlur={this.onInputChange}
          onInput={this.onInputChange}
          onKeyDown={this.onInputKeyDown}
          dangerouslySetInnerHTML={{__html: value}}
        />
      </DropZone>
    )
  }

  render() {
    const {isWorkspaceOpen} = this.props.sessionState
    if (!isWorkspaceOpen) {
      const Fallback = this.props.fallback
      return <Fallback ref="fallback" {...this.props} />
    }

    const {draft, session} = this.props
    const exposedProps = {draft, session}
    return (
      <OverlaidComponents
        className="mail-merge-subject-overlaid"
        exposedProps={exposedProps}
      >
        {this.renderContenteditable()}
      </OverlaidComponents>
    )
  }
}

export default ListensToMailMergeSession(MailMergeSubjectTextField)
