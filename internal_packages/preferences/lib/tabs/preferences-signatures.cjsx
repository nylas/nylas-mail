React = require 'react'
_ = require 'underscore'
{RetinaImg, Flexbox} = require 'nylas-component-kit'

class PreferencesSignatures extends React.Component
  @displayName: 'PreferencesSignatures'

  render: =>
    <div className="container-signatures">
      <div className="section-signaturces">
        <div className="section-title">
          Signatures
        </div>
        <div className="section-body">
          <Flexbox direction="row" style={alignItems: "top"}>
            <div style={flex: 2}>
              <div className="menu">
                <ul className="menu-items">
                  <li>Personal</li>
                  <li>Corporate</li>
                </ul>
              </div>
              <div className="menu-footer">
                <div className="menu-horizontal">
                  <ul className="menu-items">
                    <li>+</li>
                    <li>-</li>
                  </ul>
                </div>
              </div>
            </div>
            <div style={flex: 5}>
              <div className="signature-area">
                Signature
              </div>
              <div className="signature-footer">
                <button className="edit-html-button btn">Edit HTML</button>
                <div className="menu-horizontal">
                  <ul className="menu-items">
                    <li><b>B</b></li>
                    <li><i>I</i></li>
                    <li><u>u</u></li>
                  </ul>
                </div>

              </div>
            </div>
          </Flexbox>
        </div>
      </div>
    </div>

module.exports = PreferencesSignatures
