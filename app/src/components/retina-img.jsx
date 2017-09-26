import _ from 'underscore';
import { React, PropTypes, Utils } from 'mailspring-exports';

const StylesImpactedByZoom = [
  'top',
  'left',
  'right',
  'bottom',
  'paddingTop',
  'paddingLeft',
  'paddingRight',
  'paddingBottom',
  'marginTop',
  'marginBottom',
  'marginLeft',
  'marginRight',
];

const Mode = {
  ContentPreserve: 'original',
  ContentLight: 'light',
  ContentDark: 'dark',
  ContentIsMask: 'mask',
};

/*
Public: RetinaImg wraps the DOM's standard `<img`> tag and implements a `UIImage` style
interface. Rather than specifying an image `src`, RetinaImg allows you to provide
an image name. Like UIImage on iOS, it automatically finds the best image for the current
display based on pixel density. Given `image.png`, on a Retina screen, it looks for
`image@2x.png`, `image.png`, `image@1x.png` in that order. It uses a lookup table and caches
image names, so images generally resolve immediately.

RetinaImg also introduces the concept of image `modes`. Specifying an image mode
is important for theming: it describes the content of your image, allowing theme
developers to properly adjust it. The four modes are described below:

- ContentPreserve: Your image contains color or should not be adjusted by any theme.

- ContentLight: Your image is a grayscale image with light colors, intended to be shown
  against a dark background. If a theme developer changes the background to be light, they
  can safely apply CSS filters to invert or darken this image. This mode adds the
  `content-light` CSS class to the image.

- ContentDark: Your image is a grayscale image with dark colors, intended to be shown
  against a light background. If a theme developer changes the background to be dark, they
  can safely apply CSS filters to invert or brighten this image. This mode adds the
  `content-dark` CSS class to the image.

- ContentIsMask: This image provides alpha information only, and color should
  be based on the `background-color` of the RetinaImg. This mode adds the
  `content-mask` CSS class to the image, and leverages `-webkit-mask-image`.

  Example: Icons displayed within buttons specify ContentIsMask, and their
  color is declared via CSS to be the same as the button text color. Changing
  `@text-color-subtle` in a theme changes both button text and button icons!

   ```css
   .btn-icon {
     color: @text-color-subtle;
     img.content-mask { background-color: @text-color-subtle; }
   }
   ```

Section: Component Kit
*/
class RetinaImg extends React.Component {
  static displayName = 'RetinaImg';

  /*
  Public: React `props` supported by RetinaImg:

   - `mode` (required) One of the RetinaImg.Mode constants. See above for details.
   - `name` (optional) A {String} image name to display.
   - `url` (optional) A {String} url of an image to display.
      May be an http, https, or `mailspring://<packagename>/<path within package>` URL.
   - `fallback` (optional) A {String} image name to use when `name` cannot be found.
   - `selected` (optional) Appends "-selected" to the end of the image name when when true
   - `active` (optional) Appends "-active" to the end of the image name when when true
   - `style` (optional) An {Object} with additional styles to apply to the image.
   - `resourcePath` (options) Changes the default lookup location used to find the images.
  */
  static propTypes = {
    mode: PropTypes.string.isRequired,
    name: PropTypes.string,
    url: PropTypes.string,
    className: PropTypes.string,
    style: PropTypes.object,
    fallback: PropTypes.string,
    selected: PropTypes.bool,
    active: PropTypes.bool,
    resourcePath: PropTypes.string,
  };

  static Mode = Mode;

  shouldComponentUpdate = nextProps => {
    return !_.isEqual(this.props, nextProps);
  };

  _pathFor = name => {
    if (!name || typeof name !== 'string') return null;
    let pathName = name;

    const [basename, ext] = name.split('.');
    if (this.props.active === true) {
      pathName = `${basename}-active.${ext}`;
    }
    if (this.props.selected === true) {
      pathName = `${basename}-selected.${ext}`;
    }

    return Utils.imageNamed(pathName, this.props.resourcePath);
  };

  render() {
    const path =
      this.props.url || this._pathFor(this.props.name) || this._pathFor(this.props.fallback) || '';
    const pathIsRetina = path.indexOf('@2x') > 0;
    let className = this.props.className || '';

    const style = this.props.style || {};
    style.WebkitUserDrag = 'none';
    style.zoom = pathIsRetina ? 0.5 : 1;
    if (style.width) style.width /= style.zoom;
    if (style.height) style.height /= style.zoom;

    if (this.props.mode === Mode.ContentIsMask) {
      style.WebkitMaskImage = `url('${path}')`;
      style.WebkitMaskRepeat = 'no-repeat';
      style.objectPosition = '10000px';
      className += ' content-mask';
    } else if (this.props.mode === Mode.ContentDark) {
      className += ' content-dark';
    } else if (this.props.mode === Mode.ContentLight) {
      className += ' content-light';
    }

    for (const key of Object.keys(style)) {
      const val = style[key].toString();
      if (StylesImpactedByZoom.indexOf(key) !== -1 && val.indexOf('%') === -1) {
        style[key] = val.replace('px', '') / style.zoom;
      }
    }

    const otherProps = Utils.fastOmit(this.props, Object.keys(this.constructor.propTypes));
    return (
      <img alt={this.props.name} className={className} src={path} style={style} {...otherProps} />
    );
  }
}

export default RetinaImg;
