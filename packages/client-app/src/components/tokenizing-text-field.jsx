import React from 'react'
import ReactDOM from 'react-dom'
import classNames from 'classnames'
import _ from 'underscore'
import {remote} from 'electron';
import {Utils, RegExpUtils} from 'nylas-exports'
import {Menu} from 'nylas-component-kit';

import RetinaImg from './retina-img';
import KeyCommandsRegion from './key-commands-region';

class SizeToFitInput extends React.Component {
  static propTypes = {
    value: React.PropTypes.string,
  };

  constructor(props) {
    super(props)
    this.state = {};
  }

  componentDidMount() {
    this._sizeToFit()
  }

  componentDidUpdate() {
    this._sizeToFit()
  }

  _sizeToFit() {
    if (this.props.value.length === 0) {
      return;
    }
    // Measure the width of the text in the input and
    // resize the input field to fit.
    const inputEl = ReactDOM.findDOMNode(this.refs.input)
    const measureEl = ReactDOM.findDOMNode(this.refs.measure)
    measureEl.innerText = inputEl.value;
    measureEl.style.top = `${inputEl.offsetTop}px`;
    measureEl.style.left = `${inputEl.offsetLeft}px`;
    // The 10px comes from the 7.5px left padding and 2.5px more of
    // breathing room.
    inputEl.style.width = `${measureEl.offsetWidth + 10}px`;
  }

  select() {
    ReactDOM.findDOMNode(this.refs.input).select();
  }

  selectionRange() {
    const inputEl = ReactDOM.findDOMNode(this.refs.input);
    return {
      start: inputEl.selectionStart,
      end: inputEl.selectionEnd,
    };
  }

  focus() {
    ReactDOM.findDOMNode(this.refs.input).focus();
  }

  render() {
    return (
      <span>
        <span ref="measure" style={{visibility: 'hidden', position: 'absolute'}} />
        <input ref="input" type="text" style={{width: 1}} {...this.props} />
      </span>
    );
  }
}

class Token extends React.Component {
  static displayName = "Token";

  static propTypes = {
    className: React.PropTypes.string,
    selected: React.PropTypes.bool,
    valid: React.PropTypes.bool,
    item: React.PropTypes.object,
    onClick: React.PropTypes.func.isRequired,
    onDragStart: React.PropTypes.func.isRequired,
    onEdited: React.PropTypes.func,
    onAction: React.PropTypes.func,
    disabled: React.PropTypes.bool,
    onEditMotion: React.PropTypes.func,
  }

  static defaultProps = {
    className: '',
  }

  constructor(props) {
    super(props);
    this.state = {
      editing: false,
      editingValue: this.props.item.toString(),
    };
  }

  componentWillReceiveProps(props) {
    // never override the text the user is editing if they're looking at it
    if (this.state.editing) {
      return;
    }
    this.setState({editingValue: props.item.toString()});
  }

  componentDidUpdate(prevProps, prevState) {
    if (this.state.editing && !prevState.editing) {
      this.refs.input.select();
    }
  }

  _renderEditing() {
    return (
      <SizeToFitInput
        ref="input"
        className="token-editing-input"
        spellCheck="false"
        value={this.state.editingValue}
        onKeyDown={this._onEditKeydown}
        onBlur={this._onEditFinished}
        onChange={(event) => this.setState({editingValue: event.target.value})}
      />
    );
  }

  _renderViewing() {
    const classes = classNames({
      token: true,
      disabled: this.props.disabled,
      dragging: this.state.dragging,
      invalid: !this.props.valid,
      selected: this.props.selected,
    });

    let actionButton = null;
    if (this.props.onAction && !this.props.disabled) {
      actionButton = (
        <button type="button" className="action" onClick={this._onAction} tabIndex={-1}>
          <RetinaImg mode={RetinaImg.Mode.ContentIsMask} name="composer-caret.png" />
        </button>
      );
    }

    return (
      <div
        className={`${classes} ${this.props.className}`}
        onDragStart={this._onDragStart}
        onDragEnd={this._onDragEnd}
        draggable={!this.props.disabled}
        onDoubleClick={this._onDoubleClick}
        onClick={this._onClick}
      >
        {actionButton}
        {this.props.children}
      </div>
    );
  }

  _onDragStart = (event) => {
    if (this.props.disabled) return;
    this.props.onDragStart(event, this.props.item);
    this.setState({dragging: true});
  }

  _onDragEnd = () => {
    if (this.props.disabled) return;
    this.setState({dragging: false})
  }

  _onClick = (event) => {
    if (this.props.disabled) return;
    this.props.onClick(event, this.props.item);
  }

  _onDoubleClick = () => {
    if (this.props.disabled) return;
    if (this.props.onEditMotion) {
      this.props.onEditMotion(this.props.item);
    }
    if (this.props.onEdited) {
      this.setState({editing: true});
    }
  }

  _onEditKeydown = (event) => {
    if (this.props.disabled) return;
    if (event.key === "Enter" && this.props.selected && this.props.onEditMotion) {
      this.props.onEditMotion(this.props.item);
    }
    if (['Escape', 'Enter'].includes(event.key)) {
      this._onEditFinished();
    }
  }

  _onEditFinished = () => {
    if (this.props.disabled) return;
    if (this.props.onEdited) {
      this.props.onEdited(this.props.item, this.state.editingValue);
    }
    this.setState({editing: false});
  }

  _onAction = () => {
    if (this.props.disabled) return;
    this.props.onAction(this.props.item);
    event.preventDefault();
  }

  render() {
    return this.state.editing ? this._renderEditing() : this._renderViewing();
  }
}

/*
Public: The TokenizingTextField component displays a list of options as you type and converts them into stylable tokens.

It wraps the Menu component, which takes care of the typing and keyboard
interactions.

See documentation on the propTypes for usage info.

Section: Component Kit
*/
export default class TokenizingTextField extends React.Component {
  static displayName = "TokenizingTextField";

  static containerRequired = false;

  static Token = Token;

  static propTypes = {
    className: React.PropTypes.string,

    disabled: React.PropTypes.bool,

    placeholder: React.PropTypes.node,

    // An array of current tokens.
    //
    // A token is usually an object type like a `Contact`. The set of
    // tokens is stored as a prop instead of `state`. This means that when
    // the set of tokens needs to be changed, it is the parent's
    // responsibility to make that change.
    tokens: React.PropTypes.arrayOf(React.PropTypes.object),

    // The maximum number of tokens allowed. When null (the default) and
    // unlimited number of tokens may be given
    maxTokens: React.PropTypes.number,

    // A string to pre-fill the input with when the tokens are empty.
    defaultValue: React.PropTypes.string,

    // A function that, given an object used for tokens, returns a unique
    // id (key) for that object.
    //
    // This is necessary for React to assign each of the subitems and
    // unique key.
    tokenKey: React.PropTypes.func.isRequired,

    // A function that, given a token, returns true if the token is valid
    // and false if the token is invalid. Useful if your implementation of
    // onAdd allows invalid tokens to be added to the field (ie malformed
    // email addresses.) Optional.
    //
    tokenIsValid: React.PropTypes.func,

    // What each token looks like
    //
    // A function that is passed an object and should return React elements
    // to display that individual token.
    tokenRenderer: React.PropTypes.func.isRequired,

    tokenClassNames: React.PropTypes.func,

    // The function responsible for providing a list of possible options
    // given the current input.
    //
    // It takes the current input as a value and should return an array of
    // candidate objects. These objects must be the same type as are passed
    // to the `tokens` prop.
    //
    // The function may either directly return tokens, or may return a
    // Promise, that resolves with the requested tokens
    onRequestCompletions: React.PropTypes.func.isRequired,

    // What each suggestion looks like.
    //
    // This is passed through to the Menu component's `itemContent` prop.
    // See components/menu.cjsx for more info.
    completionNode: React.PropTypes.func.isRequired,

    // Gets called when we we're ready to add whatever it is we're
    // completing
    //
    // It's either passed an array of objects (the same ones used to
    // render tokens)
    //
    // OR
    //
    // It's passed the string currently in the input field. The string case
    // happens on paste and blur.
    //
    // The function doesn't need to return anything, but it is generally
    // responible for mutating the parent's state in a way that eventually
    // updates this component's `tokens` prop.
    onAdd: React.PropTypes.func.isRequired,

    // This gets fired when people try and submit a query with a break
    // character (tab, comma, semicolon, etc). It lets us the caller
    // determine how to best deal with available options.

    // If this method is not implemented we'll pick the first available
    // option in the completions
    onInputTrySubmit: React.PropTypes.func,

    // If implemented lets the caller determine when to cut a token based
    // on the current input value and the current keydown.
    shouldBreakOnKeydown: React.PropTypes.func,

    // Gets called when we remove a token
    //
    // It's passed an array of objects (the same ones used to render
    // tokens)
    //
    // The function doesn't need to return anything, but it is generally
    // responible for mutating the parent's state in a way that eventually
    // updates this component's `tokens` prop.
    onRemove: React.PropTypes.func.isRequired,

    // Gets called when an existing token is double-clicked and edited.
    // Do not provide this method if you want to disable editing.
    //
    // It's passed a token index, and the new text typed in that location.
    //
    // The function doesn't need to return anything, but it is generally
    // responible for mutating the parent's state in a way that eventually
    // updates this component's `tokens` prop.
    onEdit: React.PropTypes.func,

    // This is slightly different than onEdit. onEditMotion gets fired if
    // the user does an editing-like action on a Token. Double clicking,
    // etc. This is usefulf for when you don't want the text of the tokens
    // themselves to be editable, but want to perform some action when the
    // tokens are double clicked.
    onEditMotion: React.PropTypes.func,

    // Called when we remove and there's nothing left to remove
    onEmptied: React.PropTypes.func,

    // Called when the secondary action of the token gets invoked.
    onTokenAction: React.PropTypes.oneOfType([
      React.PropTypes.func,
      React.PropTypes.bool,
    ]),

    // Called when the input is focused
    onFocus: React.PropTypes.func,

    // A Prompt used in the head of the menu
    menuPrompt: React.PropTypes.string,

    // A classSet hash applied to the Menu item
    menuClassSet: React.PropTypes.object,

    tabIndex: React.PropTypes.number,
  };

  static defaultProps = {
    tokens: [],
    className: '',
    defaultValue: '',
    tokenClassNames: () => '',
  }

  constructor(props) {
    super(props);
    this.state = {
      inputValue: props.defaultValue || "",
      completions: [],
      selectedKeys: [],
    }
  }

  componentDidMount() {
    this._mounted = true;
    if (this.props.tokens.length === 0) {
      if (this.state.inputValue && this.state.inputValue.length > 0) {
        this._refreshCompletions(this.state.inputValue);
      }
    }
  }

  componentWillReceiveProps(newProps) {
    if (this.props.tokens.length === 0 && this.state.inputValue.length === 0) {
      const newDefaultValue = newProps.defaultValue || ""
      this.setState({inputValue: newDefaultValue});
      if (newDefaultValue.length > 0) {
        this._refreshCompletions(newDefaultValue);
      }
    }
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  // Maintaining Input State

  _onClick = (event) => {
    // Don't focus if the focus is already on an input within our field,
    // like an editable token's input
    if (event.target.tagName === 'INPUT' && ReactDOM.findDOMNode(this).contains(event.target)) {
      return;
    }
    this.focus();
  }

  _onDrop = (event) => {
    if (!event.dataTransfer.types.includes('nylas-token-items')) {
      return;
    }

    const data = event.dataTransfer.getData('nylas-token-items');
    this._onAddItemsFromJSON(data);
  }

  _onAddItemsFromJSON = (json) => {
    let items = null;

    try {
      items = JSON.parse(json, Utils.registeredObjectReviver);
    } catch (err) {
      console.error(err)
      items = null;
    }

    if (items) {
      this._addTokens(items);
    }
  }

  _onInputFocused = ({noCompletions} = {}) => {
    this.setState({focus: true});
    if (this.props.onFocus) {
      this.props.onFocus();
    }
    if (!noCompletions) {
      this._refreshCompletions();
    }
  }

  _onInputKeydown = (event) => {
    if (["Backspace", "Delete"].includes(event.key)) {
      this._removeTokens(this._selectedTokens());
    } else if (["Escape"].includes(event.key)) {
      this._refreshCompletions("", {clear: true})
    } else if (["Tab", "Enter"].includes(event.key)) {
      this._onInputTrySubmit(event);
    } else if (["ArrowLeft", "ArrowRight"].includes(event.key)) {
      const delta = event.key === 'ArrowLeft' ? -1 : 1;
      const {start} = this.refs.input.selectionRange();

      // with tokens selected, arrow keys manipulate the selection
      if (this.state.selectedKeys.length > 0) {
        this._onShiftSelection(delta, event);
        event.preventDefault();
      // without tokens selected, left arrow key at position 0 selects item
      } else if ((delta === -1) && (start === 0)) {
        this._onShiftSelection(delta, event);
        event.preventDefault();
      }
    }

    if (this.props.shouldBreakOnKeydown) {
      if (this.props.shouldBreakOnKeydown(event)) {
        event.preventDefault();
        this._onInputTrySubmit(event);
      }
    } else if (event.key === ',') { // comma
      event.preventDefault();
      this._onInputTrySubmit(event);
    }
  }

  _onSelectAll = () => {
    const {tokens, tokenKey} = this.props;
    this.setState({selectedKeys: tokens.map(t => tokenKey(t))});
  }

  _onSelectNone = () => {
    this.setState({selectedKeys: []});
  }

  _onShiftSelection = (delta, event) => {
    const multiselectModifierPresent = event.shiftKey || event.metaKey;
    const {tokenKey, tokens} = this.props;
    const {selectedKeys} = this.state;

    // select the last token on left arrow press if no tokens are selected
    if (selectedKeys.length === 0) {
      if (delta === -1) {
        const key = tokenKey(_.last(tokens));
        this.setState({selectedKeys: [key]});
      }
      return;
    }

    const headKey = _.last(selectedKeys);
    const headIdx = tokens.map(t => tokenKey(t)).indexOf(headKey)
    const nextToken = tokens[headIdx + delta];

    if (multiselectModifierPresent) {
      if (!nextToken) { return; }
      const nextKey = tokenKey(nextToken);
      const beneathHeadKey = selectedKeys[selectedKeys.length - 2];

      if (nextKey === beneathHeadKey) {
        // If the user is "walking back" their selection, deselect the head item
        // Ex: Shift+Left, Shift+Right undoes prev. Shift+left.
        this.setState({
          selectedKeys: selectedKeys.filter(t => t !== headKey),
        });
      } else {
        // If the user is expanding their selection, always filter then add to
        // ensure the last item in the array is the most recently selected.
        this.setState({
          selectedKeys: selectedKeys.filter(t => t !== nextKey).concat([nextKey]),
        });
      }
    } else {
      this.setState({
        selectedKeys: nextToken ? [tokenKey(nextToken)] : [],
      });
    }
  }

  _onInputTrySubmit = (event) => {
    if ((this.state.inputValue || "").trim().length === 0) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();

    const {inputValue, completions} = this.state;

    // default behavior
    let token = null;
    if (completions.length > 0) {
      token = this.refs.completions.getSelectedItem() || completions[0];
    }

    // allow our container to override behavior
    if (this.props.onInputTrySubmit) {
      token = this.props.onInputTrySubmit(inputValue, completions, token);
      if (typeof token === 'string') {
        this._addInputValue(token, {skipNameLookup: true});
        return;
      }
    }

    if (token) {
      this._addToken(token);
    } else {
      this._addInputValue()
    }
  }

  _onInputChanged = (event) => {
    const val = event.target.value.trimLeft()
    this.setState({
      selectedKeys: [],
      inputValue: val,
    });

    this._refreshCompletions(val);
  }

  _onInputBlurred = (event) => {
    // Not having a relatedTarget can happen when the whole app blurs. When
    // this happens we want to leave the field as-is
    if (!event.relatedTarget) {
      return;
    }

    if (event.relatedTarget === ReactDOM.findDOMNode(this)) {
      return;
    }

    this._addInputValue();
    this._refreshCompletions("", {clear: true})
    this.setState({
      selectedKeys: [],
      focus: false,
    });
  }

  _clearInput() {
    this.setState({inputValue: ""});
    this._refreshCompletions("", {clear: true});
  }

  focus() {
    this.refs.input.focus();
  }

  // Managing Tokens

  _addInputValue = (input = this.state.inputValue, options = {}) => {
    if (this._atMaxTokens()) {
      return;
    }
    if (input.length === 0) {
      return;
    }
    this.props.onAdd(input, options);
    this._clearInput();
  }

  _onClickToken = (event, token) => {
    const {tokenKey, tokens} = this.props;
    let {selectedKeys} = this.state;

    if (event.shiftKey) {
      // Expand selection from the currently selected item to the one the user
      // has clicked. We must walk the items in order so selectedKeys is
      // an ordered list.
      let headKey = _.last(selectedKeys);
      let headIdx = tokens.map(t => tokenKey(t)).indexOf(headKey);
      const clickedIdx = tokens.indexOf(token);

      if ((clickedIdx === -1) || (clickedIdx === headIdx)) {
        return;
      }

      const step = Math.max(-1, Math.min(1, clickedIdx - headIdx));

      do {
        headIdx += step;
        headKey = tokenKey(tokens[headIdx]);
        selectedKeys = selectedKeys.filter(t => t !== headKey).concat([headKey]);
      } while (headIdx !== clickedIdx);
    } else if (event.metaKey) {
      // Expand the selection to include the clicked item, without selecting
      // the items in between. If the item is already selected, deselect it.
      const key = tokenKey(token);
      if (selectedKeys.includes(key)) {
        selectedKeys = selectedKeys.filter(t => t !== key)
      } else {
        selectedKeys = selectedKeys.concat([key]);
      }
    } else {
      // Clear the selection and select just the new token
      selectedKeys = [tokenKey(token)];
    }

    this.setState({selectedKeys})
  }

  _onDragToken = (event, token) => {
    let tokens = this._selectedTokens()
    if (tokens.length === 0) {
      tokens = [token];
    }
    const json = JSON.stringify(tokens, Utils.registeredObjectReplacer);
    event.dataTransfer.setData('nylas-token-items', json);
    event.dataTransfer.setData('text/plain', tokens.map(t => t.toString()).join(', '));
    event.dataTransfer.dropEffect = "move";
    event.dataTransfer.effectAllowed = "move";
  }

  _selectedTokens() {
    return this.props.tokens.filter((t) =>
      this.state.selectedKeys.includes(this.props.tokenKey(t))
    );
  }

  _addToken = (token) => {
    if (!token) { return; }
    this._addTokens([token]);
  }

  _addTokens = (tokens) => {
    this.props.onAdd(tokens);
    // It's possible for `_addTokens` to be fired by the menu
    // asynchronously. When the tokenizing text field is in a popover it's
    // possible for it to be unmounted before the add tokens fires.
    if (this._mounted) {
      this._clearInput();
      this.focus();
    }
  }

  _removeTokens = (tokensToDelete) => {
    const {inputValue, selectedKeys} = this.state;
    const {onEmptied, onRemove, tokens, tokenKey} = this.props;

    if ((inputValue.trim().length === 0) && (tokens.length === 0) && onEmptied) {
      onEmptied();
    }

    if (tokensToDelete.length) {
      const tokensToDeleteKeys = tokensToDelete.map(t => tokenKey(t));
      onRemove(tokensToDelete);
      this.setState({
        selectedKeys: selectedKeys.filter(k => !tokensToDeleteKeys.includes(k)),
      });
    } else {
      const lastToken = _.last(tokens);
      if (lastToken) {
        const lastTokenKey = tokenKey(lastToken);
        this.setState({
          selectedKeys: selectedKeys.filter(k => k !== lastTokenKey).concat([lastTokenKey]),
        });
      }
    }
  }

  _showDefaultTokenMenu = (token) => {
    const menu = new remote.Menu()
    menu.append(new remote.MenuItem({
      click: () => this._removeTokens([token]),
      label: 'Remove',
    }));

    if (this.props.onEditMotion) {
      menu.append(new remote.MenuItem({
        label: 'Edit',
        click: () => this.props.onEditMotion(token),
      }))
    }
    menu.popup(remote.getCurrentWindow());
  }

  // Copy and Paste

  _onCut = (event) => {
    if (this.state.selectedKeys.length) {
      this._onAttachToClipboard(event);
      // clear the tokens which were selected
      this._removeTokens(this._selectedTokens())
      // clear the text in the input if some was selected
      document.execCommand('delete');
    }
  }

  _onCopy = (event) => {
    if (this.state.selectedKeys.length) {
      this._onAttachToClipboard(event);
      event.preventDefault();
    }
  }

  _onAttachToClipboard = (event) => {
    const text = this.state.selectedKeys.join(', ')
    if (event.clipboardData) {
      const json = JSON.stringify(this._selectedTokens(), Utils.registeredObjectReplacer);
      event.clipboardData.setData('text/plain', text);
      event.clipboardData.setData('nylas-token-items', json);

      const range = this.refs.input.selectionRange();
      if (range.end > 0) {
        const inputSelection = this.state.inputValue.substr(range.start, range.end - range.start);
        event.clipboardData.setData('nylas-token-input', inputSelection);
      } else {
        event.clipboardData.setData('nylas-token-input', 'null');
      }
    }
    event.preventDefault()
  }

  _onPaste = (event) => {
    const json = event.clipboardData.getData('nylas-token-items');
    const inputValue = event.clipboardData.getData('nylas-token-input');
    if (json) {
      this._onAddItemsFromJSON(json)
      if (inputValue && inputValue !== 'null') {
        this.setState({inputValue})
      }
      event.preventDefault();
      return;
    }

    const text = event.clipboardData.getData('text/plain');
    if (text) {
      const newInputValue = this.state.inputValue + text
      if (RegExpUtils.emailRegex().test(newInputValue)) {
        this._addInputValue(newInputValue, {skipNameLookup: true});
        event.preventDefault();
      } else {
        this._refreshCompletions(newInputValue);
      }
    }
  }

  // Managing Suggestions

  // Asks `this.props.onRequestCompletions` for new completions given the
  // current inputValue. Since `onRequestCompletions` can be asynchronous,
  // this function will handle calling `setState` on `completions` when
  // `onRequestCompletions` returns.
  _refreshCompletions = (val = this.state.inputValue, {clear} = {}) => {
    const usedKeys = this.props.tokens.map(this.props.tokenKey);
    const removeUsedTokens = (tokens) => {
      return tokens.filter((t) => !usedKeys.includes(this.props.tokenKey(t)));
    }

    const tokensOrPromise = this.props.onRequestCompletions(val, {clear});

    if (_.isArray(tokensOrPromise)) {
      this.setState({completions: removeUsedTokens(tokensOrPromise)})
    } else if (tokensOrPromise instanceof Promise) {
      tokensOrPromise.then((tokens) => {
        if (!this._mounted) { return; }
        this.setState({completions: removeUsedTokens(tokens)});
      });
    } else {
      console.warn("onRequestCompletions returned an invalid type. It must return an Array of tokens or a Promise that resolves to an array of tokens");
      this.setState({completions: []});
    }
  }

  // Rendering

  _inputComponent() {
    const props = {
      onCopy: this._onCopy,
      onCut: this._onCut,
      onPaste: this._onPaste,
      onKeyDown: this._onInputKeydown,
      onBlur: this._onInputBlurred,
      onFocus: this._onInputFocused,
      onChange: this._onInputChanged,
      disabled: this.props.disabled,
      tabIndex: this.props.tabIndex || 0,
      value: this.state.inputValue,
    };

    // If we can't accept additional tokens, override the events that would
    // enable additional items to be inserted
    if (this._atMaxTokens()) {
      props.className = "noop-input"
      props.onFocus = () => this._onInputFocused({noCompletions: true})
      props.onPaste = () => 'noop-input'
      props.onChange = () => 'noop'
      props.value = ''
    }
    return (
      <SizeToFitInput ref="input" spellCheck="false" {...props} />
    )
  }

  _placeholderComponent() {
    if (this.state.inputValue.length > 0 ||
        this.props.placeholder === undefined ||
        this.props.tokens.length > 0) {
      return false;
    }
    return (<div className="placeholder">{this.props.placeholder}</div>)
  }

  _atMaxTokens() {
    const {tokens, maxTokens} = this.props;
    return !maxTokens ? false : (tokens.length >= maxTokens);
  }

  _renderPromptComponent() {
    if (!this.props.menuPrompt) {
      return false;
    }
    return (<div className="tokenizing-field-label">{`${this.props.menuPrompt}:`}</div>)
  }

  _fieldComponents() {
    const {tokens, tokenKey, tokenIsValid, tokenRenderer, tokenClassNames, onTokenAction, onEdit} = this.props;

    return tokens.map((item) => {
      const key = tokenKey(item);
      const valid = tokenIsValid ? tokenIsValid(item) : true;

      const TokenRenderer = tokenRenderer
      const onAction = (onTokenAction === false) ? null : (onTokenAction || this._showDefaultTokenMenu)

      return (
        <Token
          className={tokenClassNames(item)}
          item={item}
          key={key}
          valid={valid}
          disabled={this.props.disabled}
          selected={this.state.selectedKeys.includes(key)}
          onDragStart={this._onDragToken}
          onClick={this._onClickToken}
          onEditMotion={this.props.onEditMotion}
          onEdited={onEdit}
          onAction={onAction}
        >
          <TokenRenderer token={item} />
        </Token>
      );
    });
  }

  _fieldComponent() {
    const fieldClasses = classNames({
      "tokenizing-field-input": true,
      "at-max-tokens": this._atMaxTokens(),
    })
    return (
      <KeyCommandsRegion
        key="field-component"
        ref="field-drop-target"
        localHandlers={{
          "core:select-all": this._onSelectAll,
        }}
        className="tokenizing-field-wrap"
        onClick={this._onClick}
        onDrop={this._onDrop}
      >
        {this._renderPromptComponent()}
        <div className={fieldClasses}>
          {this._placeholderComponent()}
          {this._fieldComponents()}
          {this._inputComponent()}
        </div>
      </KeyCommandsRegion>
    );
  }

  render() {
    const classSet = {};
    classSet[this.props.className] = true;

    const classes = classNames(_.extend({}, classSet, (this.props.menuClassSet || {}), {
      "tokenizing-field": true,
      "disabled": this.props.disabled,
      "focused": this.state.focus,
      "empty": (this.state.inputValue || "").trim().length === 0,
    }));

    return (
      <Menu
        className={classes}
        ref="completions"
        items={this.state.completions}
        itemKey={(item) => item.id}
        itemContext={{inputValue: this.state.inputValue}}
        itemContent={this.props.completionNode}
        headerComponents={[this._fieldComponent()]}
        onFocus={this._onInputFocused}
        onBlur={this._onInputBlurred}
        onSelect={this._addToken}
      />
    );
  }
}
