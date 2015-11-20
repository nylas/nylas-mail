
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, String, Integer, ForeignKey, \
    DateTime, Text, Boolean
from sqlalchemy.orm import relationship, backref
from session import new_engine


Base = declarative_base()


def init_db():
    # engine = new_engine(None)
    # engine.execute("CREATE DATABASE IF NOT EXISTS sendavailability "
    #                "DEFAULT CHARACTER SET utf8mb4 "
    #                "DEFAULT COLLATE utf8mb4_general_ci;")
    Base.metadata.create_all(new_engine())


class Event(Base):
    """
    A single event awaiting scheduling. Once a time has been selected by the
    user, an email will be sent and this entry deleted.
    """
    __tablename__ = 'event'

    id = Column(Integer, primary_key=True)
    title = Column(String(255))
    location = Column(Text())
    description = Column(Text())

    @property
    def organizer(self):
        return filter(lambda a: a.is_sender, self.attendees)[0]


class EventTime(Base):
    """
    A time range option for a single event. An event can have many times - the
    user will choose one to schedule the event. Time ranges are deleted when
    the event is deleted.
    """
    __tablename__ = 'eventtime'

    id = Column(Integer, primary_key=True)
    start = Column(DateTime())
    end = Column(DateTime())
    key = Column(String(255))

    event_id = Column(Integer, ForeignKey('event.id'))
    event = relationship('Event',
                         foreign_keys=[event_id],
                         backref=backref('times', lazy='dynamic'),
                         lazy='joined',
                         single_parent=True,
                         cascade="all, delete-orphan")


class Attendee(Base):
    """
    An attendee for a single event. These are not stored normalized, because
    they're short-lived and need to be reliably deleted when the event is
    deleted.
    """
    __tablename__ = 'attendee'

    id = Column(Integer, primary_key=True)

    name = Column(String(255))
    email = Column(String(255))
    is_sender = Column(Boolean())

    event_id = Column(Integer, ForeignKey('event.id'))
    event = relationship('Event',
                         foreign_keys=[event_id],
                         backref=backref('attendees', lazy='dynamic'),
                         lazy='joined',
                         single_parent=True,
                         cascade="all, delete-orphan")