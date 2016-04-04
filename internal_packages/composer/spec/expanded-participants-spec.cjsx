# _ = require "underscore"
# React = require "react"
# Fields = require '../lib/fields'
# ReactTestUtils = require('react-addons-test-utils')
# AccountContactField = require '../lib/account-contact-field'
# ExpandedParticipants = require '../lib/expanded-participants'
# {Actions} = require 'nylas-exports'
#
# describe "ExpandedParticipants", ->
#   makeField = (props={}) ->
#     @onChangeParticipants = jasmine.createSpy("onChangeParticipants")
#     @onAdjustEnabledFields = jasmine.createSpy("onAdjustEnabledFields")
#     props.onChangeParticipants = @onChangeParticipants
#     props.onAdjustEnabledFields = @onAdjustEnabledFields
#     @fields = ReactTestUtils.renderIntoDocument(
#       <ExpandedParticipants {...props} />
#     )
#
#   it "always renders to field", ->
#     makeField.call(@)
#     el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "to-field")
#     expect(el).toBeDefined()
#
#   it "renders cc when enabled", ->
#     makeField.call(@, enabledFields: [Fields.Cc])
#     el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "cc-field")
#     expect(el).toBeDefined()
#
#   it "renders bcc when enabled", ->
#     makeField.call(@, enabledFields: [Fields.Bcc])
#     el = ReactTestUtils.findRenderedDOMComponentWithClass(@fields, "bcc-field")
#     expect(el).toBeDefined()
#
#   it "renders from when enabled", ->
#     makeField.call(@, enabledFields: [Fields.From])
#     el = ReactTestUtils.findRenderedComponentWithType(@fields, AccountContactField)
#     expect(el).toBeDefined()
#
#   it "empties cc and focuses on to field", ->
#     makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
#     @fields.refs[Fields.Cc].props.onEmptied()
#     expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Cc]
#
#   it "empties bcc and focuses on to field", ->
#     makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
#     @fields.refs[Fields.Bcc].props.onEmptied()
#     expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Bcc]
#
#   it "empties bcc and focuses on cc field", ->
#     makeField.call(@, enabledFields: [Fields.Bcc, Fields.Subject])
#     @fields.refs[Fields.Bcc].props.onEmptied()
#     expect(@onAdjustEnabledFields).toHaveBeenCalledWith hide: [Fields.Bcc]
#
#   it "notifies when participants change", ->
#     makeField.call(@, enabledFields: [Fields.Cc, Fields.Bcc, Fields.Subject])
#     @fields.refs[Fields.Cc].props.change()
#     expect(@onChangeParticipants).toHaveBeenCalled()
