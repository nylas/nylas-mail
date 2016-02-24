Autolinker = require 'autolinker'
AutolinkerExtension = require '../lib/plugins/autolinker-extension'

describe "AutolinkerExtension", ->
  beforeEach ->
    spyOn(Autolinker, 'link').andCallFake (txt) => txt

  it "should call through to Autolinker", ->
    AutolinkerExtension.formatMessageBody(message: {body:'body'})
    expect(Autolinker.link).toHaveBeenCalledWith('body', {twitter: false})

  it "should add a title to everything with an href", ->
    message =
      body: """
        <a href="apple.com">hello world!</a>
        <a href = "http://apple.com">hello world!</a>
        <a href ='http://apple.com'>hello world!</a>
        <a href ='mailto://'>hello world!</a>
      """
    expected =
      body: """
        <a href="apple.com" title="apple.com" >hello world!</a>
        <a href = "http://apple.com" title="http://apple.com" >hello world!</a>
        <a href ='http://apple.com' title="http://apple.com" >hello world!</a>
        <a href ='mailto://' title="mailto://" >hello world!</a>
      """
    AutolinkerExtension.formatMessageBody({message})
    expect(message.body).toEqual(expected.body)
