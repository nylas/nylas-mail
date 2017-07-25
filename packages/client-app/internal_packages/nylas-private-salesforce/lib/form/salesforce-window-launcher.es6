import _str from 'underscore.string'
import {remote} from 'electron'
import SalesforceActions from '../salesforce-actions'

const WINDOW_TYPE = "SalesforceObjectForm"
const WIN_WIDTH = 600
const WIN_HEIGHT = 800

function isFormWindow(windowKey) {
  const re = new RegExp(WINDOW_TYPE);
  return re.test(windowKey)
}

function getScreenSize() {
  return remote.screen.getPrimaryDisplay().workAreaSize
}

function findSpotOn(dir = "right") {
  const defaultStart = dir === "right" ? 0 : 9999
  let adjustedX = defaultStart;
  let adjustedY = defaultStart;
  const allWindowDimensions = NylasEnv.getAllWindowDimensions();

  const testFn = dir === "right" ? Math.max : Math.min;

  for (const windowKey of Object.keys(allWindowDimensions)) {
    if (!isFormWindow(windowKey)) continue;
    const dims = allWindowDimensions[windowKey];
    const newX = dir === "right" ? dims.x + dims.width : dims.x - dims.width
    adjustedX = testFn(adjustedX, newX);
    adjustedY = testFn(adjustedY, dims.y);
  }
  return {adjustedX, adjustedY}
}

function calcBoundsForNextWindow() {
  const {width, height} = getScreenSize();
  const screenWidth = width
  const screenHeight = height

  // By default, center window in the screen.
  let winY = Math.round((screenHeight / 2) - (WIN_HEIGHT / 2))
  let winX = Math.round((screenWidth / 2) - (WIN_WIDTH / 2))

  let {adjustedX, adjustedY} = findSpotOn('right');
  if (adjustedX + WIN_WIDTH > screenWidth) {
    const newDims = findSpotOn('left');
    adjustedX = newDims.adjustedX
    adjustedY = newDims.adjustedY
  }
  adjustedX = Math.min(adjustedX, screenWidth - WIN_WIDTH);
  adjustedY = Math.min(adjustedY, screenHeight - WIN_HEIGHT);

  // If there are other windows, place to the right of that window.
  if (adjustedX > 0 || adjustedY > 0) {
    winX = adjustedX;
    winY = adjustedY;
  }

  return {
    x: winX,
    y: winY,
    width: WIN_WIDTH,
    height: WIN_HEIGHT,
  }
}

class SalesforceWindowLauncher {

  activate() {
    this._usub = SalesforceActions.openObjectForm.listen(this._newForm)
  }

  deactivate() {
    this._usub();
  }

  /**
   * This will create a new Salesforce Object form in a popout window
   *
   * Options:
   *   - objectType: The Salesforce objectType i.e. "Opportunity" or "Account"
   *   - objectId: OPTIONAL- If present that means we want to open an
   *     a form to edit the given objectId
   *   - objectInitialData: Some initial data to seed the creation with.
   *     It's a hash whose keys are the SalesforceObject data keys and
   *     whose values are the default values for that.
   *   - contextData: The entity that originated the call to create a
   *     new window may wish to pass some identifying information to be
   *     passed along with the call. This is useful to let the caller know
   *     when a separate window closed, or an object was created, etc.
   */
  _newForm({objectId, objectType, objectInitialData, contextData}) {
    const objName = _str.titleize(_str.humanize(objectType))
    let title = `Create New ${objName}`
    if (objectId) {
      title = `Update ${(objectInitialData || {}).Name || objName}`
    }

    NylasEnv.newWindow({
      title: title,
      bounds: calcBoundsForNextWindow(),
      windowType: WINDOW_TYPE,
      windowProps: {objectId, objectType, objectInitialData, contextData},
    })
  }
}

export default new SalesforceWindowLauncher()
