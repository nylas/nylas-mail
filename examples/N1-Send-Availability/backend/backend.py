from flask import Flask, request, render_template

from flanker import mime
from icalendar import Calendar, Event
from icalendar.prop import vCalAddress, vText
import requests

from cStringIO import StringIO

from datetime import datetime
import pytz
import time
import os

import models as m
from session import session_scope
from sqlalchemy.orm.exc import NoResultFound

app = Flask(__name__)

m.init_db()


@app.route('/register-events', methods=["POST"])
def register_events():
    """
    Accepts new event data to be stored in the database, awaiting scheduling.
    """
    data = request.get_json(force=True)

    # Save new event details and times to database
    with session_scope() as dbsession:

        conflicts = [
            dbsession.query(m.EventTime)
            .filter(m.EventTime.key == tm['serverKey']).first()
            for tm in data['times']
        ]
        if any(n is not None for n in conflicts):
            raise 'An event key conflicts with an existing key: %s' % conflicts
        times = [_make_event_time(d) for d in data['times']]
        attendees = [_make_attendee(d) for d in data['attendees']]

        event = _make_event(data["event"])
        event.times = times
        event.attendees = attendees

        dbsession.add(event)

    return ''


@app.route('/event/<key>', methods=["GET"])
def load_event(key):
    """
    Displays the scheduling page for this event, with time range for the
    passed "key" param selected.
    """
    with session_scope() as dbsession:
        try:
            etime = dbsession.query(m.EventTime).filter(m.EventTime.key == key).one()
        except NoResultFound:
            return render_template("bad_event_link.html")
        event = etime.event
        times = []
        for t in event.times:
            times.append({
                "start": timestamp(t.start),
                "end": timestamp(t.end),
                "key": t.key
            })
        return render_template("show_event.html",
                               event=event,
                               selected_key=key,
                               times_json=times)


@app.route('/event/<key>', methods=["POST"])
def schedule(key):
    """
    Schedules an event at the time range corresponding to the passed
    "key" param, by sending an email to all participants containing an
    attached ICS file.
    """
    with session_scope() as dbsession:
        try:
            etime = dbsession.query(m.EventTime).filter(m.EventTime.key == key).one()
        except NoResultFound:
            return render_template("bad_event_link.html")
        event = etime.event

        msg = _create_email(event, etime)
        _send_email(msg)

        for t in event.times:
            dbsession.delete(t)
        for a in event.attendees:
            dbsession.delete(a)
        dbsession.commit()
        dbsession.delete(event)

        return render_template('success.html')


def _create_email(event, etime):
    sender = event.organizer.email
    html_body = render_template("event_email.html", event=event, time=etime)
    text_body = render_template("event_email.txt", event=event, time=etime)
    msg = mime.create.multipart('mixed')
    ical_txt = _make_ics(event,etime)

    body = mime.create.multipart('alternative')
    body.append(
        mime.create.text('plain', text_body),
        mime.create.text('html', html_body),
        mime.create.text('calendar; method=REQUEST', ical_txt, charset='utf8')
    )
    msg.append(
        body,
        mime.create.attachment('application/ics', ical_txt, filename='event.ics', disposition='attachment', charset='utf8')
    )

    msg.headers['From'] = "scheduler@nylas.com"
    msg.headers['Reply-To'] = sender
    msg.headers['Subject'] = "Invitation: {}".format(event.title)
    msg.headers['To'] = ", ".join([a.email for a in event.attendees])

    return msg


def _send_email(msg):
    key = os.environ['MAILGUN_KEY']
    requests.post(
        "https://api.mailgun.net/v3/mg.nylas.com/messages.mime",
        auth=("api", key),
        data={"to": msg.headers["To"]},
        files={"message": StringIO(msg.to_string())}
    )


def _make_ics(event, etime):

    cal = Calendar()
    cal.add('prodid', 'N1-send-availability-package')
    cal.add('version', '2.0')

    cal.add('method', 'REQUEST')   # also have PUBLISH or CANCEL

    evt = Event()
    evt.add('summary', event.title)
    evt.add('location', event.location)
    evt.add('description', event.description)
    evt.add('dtstart', etime.start.replace(tzinfo=pytz.UTC))
    evt.add('dtend', etime.end.replace(tzinfo=pytz.UTC))
    evt.add('dtstamp', datetime.now(pytz.UTC))

    evt['uid'] = '{timestamp}/{email}'.format(
        timestamp=time.mktime(datetime.now(pytz.UTC).timetuple()),
        email=event.organizer.email
    )
    evt.add('priority', 5)

    organizer = vCalAddress('MAILTO:{}'.format(event.organizer.email))
    organizer.params['cn'] = vText(event.organizer.name)
    organizer.params['role'] = vText('CHAIR')
    evt['organizer'] = organizer

    for attendee in event.attendees:
        atnd = vCalAddress('MAILTO:{}'.format(attendee.email))
        atnd.params['cn'] = vText(attendee.name)
        atnd.params['ROLE'] = vText('REQ-PARTICIPANT')
        evt.add('attendee', atnd, encode=0)

    cal.add_component(evt)

    return cal.to_ical()


def _make_event_time(time_data):
    return m.EventTime(start=datetime.utcfromtimestamp(int(time_data['start'])),
                       end=datetime.utcfromtimestamp(int(time_data['end'])),
                       key=time_data['serverKey'])


def _make_event(event_data):
    return m.Event(title=event_data["title"],
                   description=event_data["description"],
                   location=event_data["location"])


def _make_attendee(attendee_data):
    return m.Attendee(name=attendee_data["name"],
                      email=attendee_data["email"],
                      is_sender=attendee_data["isSender"])


def timestamp(dt):
    'Return POSIX timestamp as float'
    return (dt - datetime.utcfromtimestamp(0)).total_seconds()

if __name__ == '__main__':
    app.run(port=8888, debug=True)
