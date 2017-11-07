import React from 'react';
import { clipboard } from 'electron';
import { MailspringAPIRequest } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';

function buildShareHTML(htmlEl, styleEl) {
  return `
    <html lang="en">
    <head>
    <meta charset="utf-8"> 
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <meta name="author" content="Mailspring">
    <title>Mailspring Activity</title>
    <style type="text/css">
    body {
      font-family: sans-serif;
      font-size: 14px;
      margin: 40px auto;
      max-width: 1000px;
    }
    .hidden-on-web {
      display: none !important;
    }
    </style>
    ${styleEl.outerHTML}
    </head>
    <body>
    ${htmlEl.outerHTML}
    <script>
      Array.from(document.querySelectorAll('.visible')).forEach((el) => {
        el.classList.remove('visible');
        setTimeout(() => {
          el.classList.add('visible');
        }, 250);
      });
    </script>
    </body>
    </html>
`;
}

export default class ShareButton extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      loading: false,
      link: null,
    };
  }

  componentDidMount() {
    this._mounted = true;
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _onShareReport = async () => {
    this.setState({
      loading: true,
    });

    const json = await MailspringAPIRequest.makeRequest({
      server: 'identity',
      method: 'POST',
      path: '/api/share-static-page',
      json: true,
      body: {
        key: `activity-${Date.now()}`,
        html: buildShareHTML(
          document.querySelector('style[source-path*="activity/styles/index.less"]'),
          document.querySelector('.activity-dashboard')
        ),
      },
      timeout: 1500,
    });
    if (!this._mounted) {
      return;
    }
    this.setState(
      {
        loading: false,
        link: json.link,
      },
      () => {
        if (this._linkEl) {
          this._linkEl.setSelectionRange(0, this._linkEl.value.length);
          this._linkEl.focus();
        }
      }
    );
  };

  render() {
    return (
      <div style={{ display: 'flex' }}>
        <div className="btn" onClick={this._onShareReport} style={{ width: 150 }}>
          Share this Report
          {this.state.loading && (
            <RetinaImg
              name="inline-loading-spinner.gif"
              mode={RetinaImg.Mode.ContentDark}
              style={{ width: 14, height: 14, marginLeft: 10 }}
            />
          )}
        </div>
        {this.state.link && (
          <div>
            <input
              ref={el => (this._linkEl = el)}
              type="url"
              value={this.state.link}
              style={{ width: 300, marginLeft: 10 }}
              readOnly
            />
            <div className="copy-to-clipboard" onClick={() => clipboard.writeText(this.state.link)}>
              <RetinaImg name="icon-copytoclipboard.png" mode={RetinaImg.Mode.ContentIsMask} />
            </div>
          </div>
        )}
      </div>
    );
  }
}
