import React from 'react';
import {mount} from 'enzyme';
import {ButtonDropdown, RetinaImg} from 'nylas-component-kit';
import {Actions, Message, SendActionsStore} from 'nylas-exports';
import SendActionButton from '../lib/send-action-button';

const {UndecoratedSendActionButton} = SendActionButton;

const {DefaultSendAction} = SendActionsStore

const GoodSendAction = {
  title: "Good Send Action",
  configKey: 'good-send-action',
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const SecondSendAction = {
  title: "Second Send Action",
  configKey: 'second-send-action',
  isAvailableForDraft: () => true,
  performSendAction: () => {},
}

const NoIconUrl = {
  title: "No Icon",
  configKey: 'no-icon',
  iconUrl: null,
  isAvailableForDraft: () => true,
  performSendAction() {},
}

describe('SendActionButton', function describeBlock() {
  beforeEach(() => {
    spyOn(NylasEnv, 'reportError')
    spyOn(Actions, 'sendDraft')
    this.isValidDraft = jasmine.createSpy('isValidDraft')
    this.clientId = "client-23"
    this.draft = new Message({clientId: this.clientId, draft: true})
  })

  const render = (draft, {isValid = true, sendActions = [], ordered = {}} = {}) => {
    this.isValidDraft.andReturn(isValid)
    return mount(
      <UndecoratedSendActionButton
        draft={draft}
        isValidDraft={this.isValidDraft}
        sendActions={[DefaultSendAction].concat(sendActions)}
        orderedSendActions={{
          preferred: ordered.preferred || DefaultSendAction,
          rest: ordered.rest || [],
        }}
      />
    )
  }

  it("renders without error", () => {
    const sendActionButton = render(this.draft);
    expect(sendActionButton.is(UndecoratedSendActionButton)).toBe(true);
  });

  it("initializes with the default and shows the standard Send option", () => {
    const sendActionButton = render(this.draft);
    const button = sendActionButton.find('button').first();
    expect(button.text()).toEqual('Send');
  });

  it("is a single button when there are no send actions", () => {
    const sendActionButton = render(this.draft, {sendActions: []});
    const dropdowns = sendActionButton.find(ButtonDropdown);
    const buttons = sendActionButton.find('button');
    expect(buttons.length).toBe(1);
    expect(dropdowns.length).toBe(0);
    expect(buttons.first().text()).toBe('Send');
  });

  it("is a dropdown when there's more than one send action", () => {
    const sendActionButton = render(this.draft, {
      sendActions: [GoodSendAction],
    });
    const dropdowns = sendActionButton.find(ButtonDropdown);
    const buttons = sendActionButton.find('button');
    expect(buttons.length).toBe(0);
    expect(dropdowns.length).toBe(1);
    expect(dropdowns.first().prop('primaryTitle')).toBe('Send');
  });

  it("has the correct primary item", () => {
    const sendActionButton = render(this.draft, {
      sendActions: [GoodSendAction, SecondSendAction],
      ordered: {preferred: SecondSendAction, rest: [DefaultSendAction, GoodSendAction]},
    });
    const dropdown = sendActionButton.find(ButtonDropdown).first();
    expect(dropdown.prop('primaryTitle')).toBe("Second Send Action");
  });

  it("still renders with a null iconUrl and doesn't show the image", () => {
    const sendActionButton = render(this.draft, {
      sendActions: [NoIconUrl],
      ordered: {preferred: NoIconUrl, rest: [DefaultSendAction]},
    });
    const dropdowns = sendActionButton.find(ButtonDropdown);
    const buttons = sendActionButton.find('button');
    const icons = sendActionButton.find(RetinaImg)
    expect(buttons.length).toBe(0);
    expect(dropdowns.length).toBe(1);
    expect(icons.length).toBe(3);
  });

  it("sends a draft by default if no extra actions present", () => {
    const sendActionButton = render(this.draft);
    const button = sendActionButton.find('button').first();
    button.simulate('click')
    expect(this.isValidDraft).toHaveBeenCalled();
    expect(Actions.sendDraft).toHaveBeenCalledWith(this.draft.clientId, 'send');
  });

  it("doesn't send a draft if the isValidDraft fails", () => {
    const sendActionButton = render(this.draft, {isValid: false});
    const button = sendActionButton.find('button').first();
    button.simulate('click')
    expect(this.isValidDraft).toHaveBeenCalled();
    expect(Actions.sendDraft).not.toHaveBeenCalled();
  });

  it("does the preferred action when more than one action present", () => {
    const sendActionButton = render(this.draft, {
      sendActions: [GoodSendAction],
      ordered: {preferred: GoodSendAction, rest: [DefaultSendAction]},
    });
    const button = sendActionButton.find('.primary-item').first();
    button.simulate('click')
    expect(this.isValidDraft).toHaveBeenCalled();
    expect(Actions.sendDraft).toHaveBeenCalledWith(this.draft.clientId, 'good-send-action');
  });
});
