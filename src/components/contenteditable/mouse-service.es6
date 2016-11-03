import { DOMUtils } from 'nylas-exports';
import ContenteditableService from './contenteditable-service';

class MouseService extends ContenteditableService {
  constructor(...args) {
    super(...args);
    this.setup();
    this.timer = null;
    this._inFrame = true;
  }

  eventHandlers() {
    return {
      onClick: this._onClick,
      onMouseOver: this._onMouseOver,
      onMouseEnter: () => { this._inFrame = true },
      onMouseLeave: () => { this._inFrame = false },
    };
  }

  // NOTE: We can't use event.preventDefault() here for <a> tags because
  // the window-event-handler.coffee file has already caught the event.

  // We use global listeners to determine whether or not dragging is
  // happening. This is because dragging may stop outside the scope of
  // this element. Note that the `dragstart` and `dragend` events don't
  // detect text selection. They are for drag & drop.
  setup() {
    window.addEventListener("mousedown", this._onMouseDown);
    window.addEventListener("mouseup", this._onMouseUp);
  }

  teardown() {
    window.removeEventListener("mousedown", this._onMouseDown);
    window.removeEventListener("mouseup", this._onMouseUp);
  }

  _onClick = (event) => {
    // We handle mouseDown, mouseMove, mouseUp, but we want to stop propagation
    // of `click` to make it clear that we've handled the event.
    // Note: Related to composer-view#_onClickComposeBody
    return event.stopPropagation();
  }

  _onMouseDown = (event) => {
    this._mouseDownEvent = event;
    this._mouseHasMoved = false;
    window.addEventListener("mousemove", this._onMouseMove);

    // We can't use the native double click event because that only fires
    // on the second up-stroke
    if (Date.now() - (this._lastMouseDown || 0) < 250) {
      this._onDoubleDown(event);
      this._lastMouseDown = 0; // to prevent triple down
    } else {
      this._lastMouseDown = Date.now();
    }
  }

  _onDoubleDown = (event) => {
    const editable = this.innerState.editableNode;
    if (editable == null) {
      return;
    }
    if (editable === event.target || editable.contains(event.target)) {
      this.setInnerState({doubleDown: true});
    }
  }

  _onMouseMove = () => {
    if (!this._mouseHasMoved) {
      this._onDragStart(this._mouseDownEvent);
      this._mouseHasMoved = true;
    }
  }

  _onMouseUp = (event) => {
    window.removeEventListener("mousemove", this._onMouseMove);

    if (this.innerState.doubleDown) {
      this.setInnerState({doubleDown: false});
    }

    if (this._mouseHasMoved) {
      this._mouseHasMoved = false;
      this._onDragEnd(event);
    }

    const {editableNode} = this.innerState;
    const selection = document.getSelection();
    if (!DOMUtils.selectionInScope(selection, editableNode)) {
      return;
    }

    this.dispatchEventToExtensions("onClick", event);
  }

  _onDragStart = (event) => {
    const editable = this.innerState.editableNode;
    if (editable == null) {
      return;
    }
    if (editable === event.target || editable.contains(event.target)) {
      this.setInnerState({dragging: true});
    }
  }

  _onDragEnd = () => {
    if (this.innerState.dragging) {
      this.setInnerState({dragging: false});
    }
  }

  // Floating toolbar plugins need to know what we're currently hovering
  // over. We take care of debouncing the event handlers here to prevent
  // flooding plugins with events.
  _onMouseOver = () => {
    // @setInnerState hoveringOver: event.target
  }
}

export default MouseService;
