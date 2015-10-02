React = require "react/addons"
ReactTestUtils = React.addons.TestUtils
EventedIFrame = require '../../src/components/evented-iframe'

describe 'EventedIFrame', ->
  describe 'link clicking behavior', ->

    beforeEach ->
      @frame = ReactTestUtils.renderIntoDocument(
        <EventedIFrame src="about:blank" />
      )

      @setAttributeSpy = jasmine.createSpy('setAttribute')
      @preventDefaultSpy = jasmine.createSpy('preventDefault')
      @openLinkSpy = jasmine.createSpy("openLink")

      @oldOpenLink = atom.windowEventHandler.openLink
      atom.windowEventHandler.openLink = @openLinkSpy

      @fakeEvent = (href) =>
        stopPropagation: ->
        preventDefault: @preventDefaultSpy
        target:
          getAttribute: (attr) -> return href
          setAttribute: @setAttributeSpy

    afterEach ->
      atom.windowEventHandler.openLink = @oldOpenLink

    it 'works for acceptable link types', ->
      hrefs = [
        "http://nylas.com"
        "https://www.nylas.com"
        "mailto:evan@nylas.com"
        "tel:8585311718"
        "custom:www.nylas.com"
      ]
      for href, i in hrefs
        @frame._onIFrameClick(@fakeEvent(href))
        expect(@setAttributeSpy).not.toHaveBeenCalled()
        expect(@openLinkSpy).toHaveBeenCalled()
        target = @openLinkSpy.calls[i].args[0].target
        expect(target.getAttribute('href')).toBe href

    it 'corrects relative uris', ->
      hrefs = [
        "nylas.com"
        "www.nylas.com"
      ]
      for href, i in hrefs
        @frame._onIFrameClick(@fakeEvent(href))
        expect(@setAttributeSpy).toHaveBeenCalled()
        modifiedHref = @setAttributeSpy.calls[i].args[1]
        expect(modifiedHref).toBe "http://#{href}"

    it 'corrects protocol-relative uris', ->
      hrefs = [
        "//nylas.com"
        "//www.nylas.com"
      ]
      for href, i in hrefs
        @frame._onIFrameClick(@fakeEvent(href))
        expect(@setAttributeSpy).toHaveBeenCalled()
        modifiedHref = @setAttributeSpy.calls[i].args[1]
        expect(modifiedHref).toBe "https:#{href}"

    it 'disallows malicious uris', ->
      hrefs = [
        "file://usr/bin/bad"
      ]
      for href in hrefs
        @frame._onIFrameClick(@fakeEvent(href))
        expect(@preventDefaultSpy).toHaveBeenCalled()
        expect(@openLinkSpy).not.toHaveBeenCalled()

