var ipc = require("ipc");
var React = require('react');
var _ = require('underscore');
var LinkedValueUtils = require('react/lib/LinkedValueUtils');
var ReactDOMComponent = require('react/lib/ReactDOMComponent');
var methods = Object.keys(ReactDOMComponent.BackendIDOperations);
var invocationTargets = [];

var sources = {
  CSSPropertyOperations: require('react/lib/CSSPropertyOperations'),
  DOMPropertyOperations: require('react/lib/DOMPropertyOperations'),
  DOMChildrenOperations: require('react/lib/DOMChildrenOperations'),
  ReactDOMIDOperations: require('react/lib/ReactDOMIDOperations'),
  ReactDOMSelect: require('react/lib/ReactDOMSelect')
}

var Custom = {
  sendSelectCurrentValue: function() {
    var reactid = this.getDOMNode().dataset.reactid;
    var target = invocationTargetForReactId(reactid);
    if (target) {
      var value = LinkedValueUtils.getValue(this);
      target.send({
        parent: 'Custom',
        sel: 'setSelectCurrentValue',
        arguments: [reactid, LinkedValueUtils.getValue(this)]
      });
    }
  }
};

var invocationTargetForReactId = function(id) {
  for (var ii = 0; ii < invocationTargets.length; ii++) {
    var target = invocationTargets[ii];
    if (id.substr(0, target.reactid.length) == target.reactid) {
      return target;
    }
    if (target.reactid == 'not-yet-rendered') {
      var node = document.querySelector("[data-reactid='"+id+"']");
      while (node = node.parentNode) {
        if (node == target.container) {
          return target;
        }
      }
    }
  }
  return null;
};

var observeMethod = function(parent, sel, callback) {
  var owner = sources[parent];
  if (!owner[sel]) {
    owner = owner.prototype;
  }

  var oldImpl = owner[sel];
  owner[sel] = function() {
    oldImpl.apply(this, arguments);

    if (invocationTargets.length == 0)
     return;

    callback.apply(this, arguments);
  }
};

var observeMethodAndBroadcast = function(parent, sel) {
  observeMethod(parent, sel, function() {
   var id = null;
   var target = null;
   var firstArgType = null;

   var args = [];
   for (var ii = 0; ii < arguments.length; ii ++) {
     args.push(arguments[ii]);
   }

   if (arguments[0] instanceof Node) {
     args[0] = args[0].dataset.reactid;
     target = invocationTargetForReactId(args[0]);
     firstArgType = "node";

   } else if (typeof(args[0]) === 'string') {
     target = invocationTargetForReactId(args[0]);
     firstArgType = "id";

   } else if (args[0] instanceof Array) {
     for (var ii = 0; ii < args[0].length; ii ++) {
       args[0][ii].parentNode = args[0][ii].parentNode.dataset.reactid;
     }
     target = invocationTargetForReactId(args[0][0].parentNode);
     firstArgType = "array";
   }

   if (target) {
     target.send({
       parent: parent,
       sel: sel,
       arguments: args,
       firstArgType: firstArgType
     });
     target.sendSizingInformation();
   }
 });
};

setTimeout(function(){
  observeMethodAndBroadcast('CSSPropertyOperations', 'setValueForStyles');
  observeMethodAndBroadcast('DOMChildrenOperations', 'updateTextContent');
  observeMethodAndBroadcast('DOMChildrenOperations', 'dangerouslyReplaceNodeWithMarkup');
  observeMethodAndBroadcast('DOMPropertyOperations', 'deleteValueForProperty');
  observeMethodAndBroadcast('DOMPropertyOperations', 'setValueForProperty');
  observeMethodAndBroadcast('ReactDOMIDOperations', 'updateInnerHTMLByID');
  observeMethodAndBroadcast('DOMChildrenOperations', 'processUpdates');
  observeMethod('ReactDOMSelect', 'componentDidUpdate', Custom.sendSelectCurrentValue);
  observeMethod('ReactDOMSelect', 'componentDidMount', Custom.sendSelectCurrentValue);
}, 10);

ipc.on('from-react-remote-window', function(json) {
  var container = null;
  for (var ii = 0; ii < invocationTargets.length; ii ++) {
    if (invocationTargets[ii].windowId == json.windowId) {
      container = invocationTargets[ii].container;
    }
  }
  if (!container) {
    console.error("Received message from child window "+json.windowId+" which is not recognized.");
    return;
  }

  if (json.event) {
    var rep = json.event;
    if (rep.targetReactId) {
      rep.target = document.querySelector(["[data-reactid='"+rep.targetReactId+"']"]);
    }
    if (rep.target && (rep.targetValue !== undefined)) {
      rep.target.value = rep.targetValue;
    }
    if (rep.target && (rep.targetChecked !== undefined)) {
      rep.target.checked = rep.targetChecked;
    }

    var EventClass = {
      "MouseEvent": MouseEvent,
      "KeyboardEvent": KeyboardEvent,
      "FocusEvent": FocusEvent
    }[rep.eventClass] || Event;

    var e = new EventClass(rep.eventType, rep);

    process.nextTick(function() {
      if (rep.target) {
        rep.target.dispatchEvent(e);
      } else {
        container.dispatchEvent(e);
      }
    });
  }
});

var parentListenersAttached = false;
var reactRemoteContainer = document.createElement('div');
reactRemoteContainer.style.left = '-10000px';
reactRemoteContainer.style.top = '40px';
reactRemoteContainer.style.backgroundColor = 'white';
reactRemoteContainer.style.position = 'absolute';
reactRemoteContainer.style.zIndex = 10000;
reactRemoteContainer.style.border = '5px solid orange';
document.body.appendChild(reactRemoteContainer);

var reactRemoteContainerTitle = document.createElement('div');
reactRemoteContainerTitle.style.color = 'white';
reactRemoteContainerTitle.style.backgroundColor = 'orange';
reactRemoteContainerTitle.innerText = 'React Remote Container';
reactRemoteContainer.appendChild(reactRemoteContainerTitle);

var toggleContainerVisible = function() {
  if (reactRemoteContainer.style.left === '-10000px') {
    reactRemoteContainer.style.left = 0;
  } else {
    reactRemoteContainer.style.left = '-10000px';
  }
};

var openWindowForComponent = function(Component, options) {
  // If a tag is specified, see if we can find an existing window to bring to foreground
  if (options.tag) {
    for (var ii = 0; ii < invocationTargets.length; ii++) {
      if (invocationTargets[ii].tag === options.tag) {
        invocationTargets[ii].window.focus();
        return;
      }
    }
  }

  var remote = require('remote');
  var url = require('url');
  var BrowserWindow = remote.require('browser-window');

  // Read rendered styles out of the page
  var styles = document.querySelectorAll("style");
  var thinStyles = "";
  for (var ii = 0; ii < styles.length; ii++) {
    var styleNode = styles[ii];
    if (!styleNode.sourcePath) {
      continue;
    }
    if ((styleNode.sourcePath.indexOf('index') > 0) || (options.stylesheetRegex && options.stylesheetRegex.test(styleNode.sourcePath))) {
      thinStyles = thinStyles + styleNode.innerText;
    }
  }

  // Create a browser window
  var thinWindowUrl = url.format({
    protocol: 'file',
    pathname: atom.getLoadSettings().resourcePath+"/static/react-remote-child.html",
    slashes: true
  });
  var thinWindow = new BrowserWindow({
    title: options.title || "",
    frame: process.platform !== 'darwin',
    width: options.width || 800,
    height: options.height || 600,
    resizable: options.resizable,
    show: false
  });
  thinWindow.loadUrl(thinWindowUrl);
  if (process.platform !== 'darwin') {
    thinWindow.setMenu(null);
  }

  // Add a container to our local document to hold the root component of the window
  var container = document.createElement('div');
  container.id = 'react-remote-window-container-'+thinWindow.id;
  if (options.width) {
    container.style.width = options.width+'px';
  } else {
    container.style.height = 'auto';
  }
  if (options.height) {
    container.style.height = options.height+'px';
  } else {
    container.style.height = 'auto';
  }
  reactRemoteContainer.appendChild(container);

  var cleanup = function() {
    if (container == null) {
      return;
    }
    for (var ii = 0; ii < invocationTargets.length; ii++) {
      if (invocationTargets[ii].container === container) {
        invocationTargets[ii].windowReady = false
        invocationTargets[ii].window = null
        invocationTargets.splice(ii, 1);
        break;
      }
    }
    reactRemoteContainer.removeChild(container);
    console.log("Cleaned up react remote window");
    container = null;
    thinWindow = null;
  };

  var sendWaiting = [];

  var sendSizingInformation = function() {
    if (!options.autosize) {
      return;
    }
    if (!thinWindow) {
      return;
    }
    // Weirdly, this returns an array of [width, height] and not a hash
    var size = thinWindow.getContentSize();
    var containerSize = container.getBoundingClientRect();
    var changed = false;
    if ((!options.height) && (size[1] != containerSize.height)) {
      size[1] = containerSize.height;
      changed = true;
    }
    if ((!options.width) && (size[0] != containerSize.width)) {
      size[0] = containerSize.width;
      changed = true;
    }
    if (containerSize.height == 0) {
      debugger;
    }
    if (changed) {
      thinWindow.setContentSize(size[0], size[1]);
    }
  };

  // Create a "Target" object that we'll use to store information about the
  // remote window, it's reactId, etc.
  var target = {
    container: container,
    containerReady: false,
    window: thinWindow,
    windowReady: false,
    windowId: thinWindow.id,
    tag: options.tag,
    reactid: 'not-yet-rendered',
    send: function(args) {
      if (target.containerReady && target.windowReady) {
        thinWindow.webContents.send('to-react-remote-window', args);
      } else {
        sendWaiting.push(args);
      }
    },
    sendSizingInformation: _.debounce(function() {
      if (target.containerReady && target.windowReady) {
        sendSizingInformation();
      }
    }, 20),
    sendHTMLIfReady: function() {
      if (target.containerReady && target.windowReady) {
        sendSizingInformation();
        thinWindow.webContents.send('to-react-remote-window', {
          html: container.innerHTML,
          style: thinStyles,
          waiting: sendWaiting
        });
      }
    }
  };
  invocationTargets.push(target);

  // Finally, render the react component into our local container and open
  // the browser window. When both of these things finish, we send the html
  // css, and any observed method invocations that occurred during the first
  // React cycle (componentDidMount).
  React.render(React.createElement(Component), container, function() {
    target.reactid = container.firstChild.dataset.reactid,
    target.containerReady = true;
    target.sendHTMLIfReady();
  });

  thinWindow.on('closed', cleanup);
  thinWindow.webContents.on('crashed', cleanup);
  thinWindow.webContents.on('did-finish-load', function () {
    target.windowReady = true;
    target.sendHTMLIfReady();
  });

  // The first time a remote window is opened, add event listeners to our
  // own window so that we close dependent windows when we're closed.
  if (parentListenersAttached == false) {
    remote.getCurrentWindow().on('close', function() {
      for (var ii = 0; ii < invocationTargets.length; ii++) {
        invocationTargets[ii].window.close();
      }
      invocationTargets = [];
    })
    parentListenersAttached = true;
  }
};

module.exports = {
  openWindowForComponent: openWindowForComponent,
  toggleContainerVisible: toggleContainerVisible
};
