var _ = require('underscore')
var container = document.getElementById("container");
var ipc = require('electron').ipcRenderer;
var lastSelectionData = {}

document.body.classList.add("platform-"+process.platform);
document.body.classList.add("window-type-react-remote");

exp = require('./selection-listeners.js');
restoreSelection = exp.restoreSelection;
getSelectionData = exp.getSelectionData;

var receiveEvent = function (json) {
  var remote = require('remote');

  if (json.selectionData) {
    document.removeEventListener("selectionchange", selectionChange);
    restoreSelection(json.selectionData)
    document.addEventListener("selectionchange", selectionChange);
  }

  if (json.html) {
    var browserWindow = remote.getCurrentWindow();
    browserWindow.on('focus', function() {
      document.body.classList.remove('is-blurred')
    });
    browserWindow.on('blur', function() {
      document.body.classList.add('is-blurred')
    });

    container.innerHTML = json.html;
    var style = document.createElement('style');
    style.onload = function() {
      for (var ii = 0; ii < json.waiting.length; ii ++) {
        receiveEvent(json.waiting[ii]);
      }
      window.requestAnimationFrame(function() {
        browserWindow.show();
      });
    };
    style.textContent = json.style;
    document.body.appendChild(style);
  }

  if (json.sel) {
    var React = require('react');
    var ReactMount = require('react/lib/ReactMount');

    ReactMount.getNode = function(id) {
      return document.querySelector("[data-reactid='"+id+"']");
    };

    var sources = {
      CSSPropertyOperations: require('react/lib/CSSPropertyOperations'),
      DOMPropertyOperations: require('react/lib/DOMPropertyOperations'),
      DOMChildrenOperations: require('react/lib/DOMChildrenOperations'),
      ReactDOMIDOperations: require('react/lib/ReactDOMIDOperations'),
      Custom: {
        setSelectCurrentValue: function(reactid, value) {
          var children = ReactMount.getNode(reactid).childNodes;
          for (var ii = 0; ii < children.length; ii ++) {
            children[ii].selected = (children[ii].value == value);
          }
        }
      }
    };

    if (json.firstArgType == 'node') {
      json.arguments[0] = ReactMount.getNode(json.arguments[0]);
    } else if (json.firstArgType == 'array') {
      for (var ii = 0; ii < json.arguments[0].length; ii ++) {
        json.arguments[0][ii].parentNode = ReactMount.getNode(json.arguments[0][ii].parentNode)
      }
    }
    sources[json.parent][json.sel].apply(sources[json.parent], json.arguments);
  }
};

ipc.on("to-react-remote-window", receiveEvent);

var events = ['keypress', 'keydown', 'keyup', 'change', 'submit', 'click', 'focus', 'blur', 'input', 'select'];
events.forEach(function(type) {
  container.addEventListener(type, function(event) {
    var representation = {
      eventType: event.type,
      eventClass: event.constructor.name,
      pageX: event.pageX,
      pageY: event.pageY,
      bubbles: event.bubbles,
      cancelable: event.cancelable,
      clientX: event.clientX,
      clientY: event.clientY,
      charCode: event.charCode,
      keyCode: event.keyCode,
      detail: event.detail,
      eventPhase: event.eventPhase
    }
    if (event.target) {
      representation.targetReactId = event.target.dataset.reactid;
    }
    if (event.target.contentEditable=="true") {
      representation.targetValue = event.target.innerHTML;
    }
    else if (event.target.value !== undefined) {
      representation.targetValue = event.target.value;
    }
    if (event.target.checked !== undefined) {
      representation.targetChecked = event.target.checked;
    }

    var remote = require('remote');
    ipc.send("from-react-remote-window", {windowId: remote.getCurrentWindow().id, event: representation});
    if ((event.type != 'keydown') && (event.type != 'keypress') && (event.type != 'keyup')) {
      event.preventDefault();
    }
  }, true);
});


selectionChange = function() {
  selectionData = getSelectionData()
  if (_.isEqual(selectionData, lastSelectionData)) { return; }
  lastSelectionData = _.clone(selectionData)
  var remote = require('remote');
  remote.getCurrentWindow().id
  ipc.send("from-react-remote-window-selection", selectionData);
}
// document.addEventListener("selectionchange", selectionChange);
