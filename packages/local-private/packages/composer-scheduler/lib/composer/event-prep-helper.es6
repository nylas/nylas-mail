export const prepareEvent = (inEvent, draft, proposals = []) => {
  const event = inEvent
  if (!event.title) {
    event.title = "";
  }

  event.participants = draft.participants().map((contact) => {
    return {
      name: contact.name,
      email: contact.email,
      status: "noreply",
    }
  })

  if (proposals.length > 0) {
    event.end = null
    event.start = null
  }
  return event;
}
