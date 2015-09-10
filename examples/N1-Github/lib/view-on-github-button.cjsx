shell = require 'shell'
React = require 'react'
GithubStore = require './github-store'
{RetinaImg} = require 'nylas-component-kit'

class ViewOnGithubButton extends React.Component
  @displayName: "ViewOnGithubButton"
  @containerRequired: false

  constructor: (@props) ->
    @state = link: null

  componentDidMount: =>
    @_unlisten = GithubStore.listen =>
      @setState link: GithubStore.link()
    @_keymapUnlisten = atom.commands.add 'body', {
      'github:open': @_openLink
    }

  componentWillUnmount: =>
    @_unlisten?()
    @_keymapUnlisten?.dispose()

  render: ->
    return null unless @state.link
    <button className="btn btn-toolbar"
            onClick={@_openLink}
            data-tooltip={"Visit Thread on GitHub"}><RetinaImg mode={RetinaImg.Mode.ContentIsMask} url="nylas://github/assets/github@2x.png" /></button>

  _openLink: =>
    shell.openExternal(@state.link) if @state.link

module.exports = ViewOnGithubButton
