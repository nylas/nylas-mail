
from contextlib import contextmanager

from sqlalchemy.orm.session import Session
from sqlalchemy import create_engine
import os


cached_engine = None


def new_engine(database="sendavailability"):
    db_url = os.environ['CLEARDB_DATABASE_URL']
    if db_url:
        uri = 'mysql+pymysql'+db_url[5:].split('?')[0]
    else:
        uri_template = ("mysql+pymysql://{username}:{password}@{host}:"
                        "{port}/{database}")
        uri = uri_template.format(username="root",
                                  password="root",
                                  host="localhost",
                                  port=3307,
                                  database=database if database else '')
    return create_engine(uri,
                         isolation_level='READ COMMITTED',
                         echo=False,
                         connect_args={'charset': 'utf8mb4'})


def new_session(engine, versioned=True):
    """Returns a session bound to the given engine."""
    session = Session(bind=engine, autoflush=True, autocommit=False)
    return session


@contextmanager
def session_scope(debug=False):
    """
    Provide a transactional scope around a series of operations.

    Takes care of rolling back failed transactions and closing the session
    when it goes out of scope.

    Note that sqlalchemy automatically starts a new database transaction when
    the session is created, and restarts a new transaction after every commit()
    on the session. Your database backend's transaction semantics are important
    here when reasoning about concurrency.

    Parameters
    ----------
    versioned : bool
        Do you want to enable the transaction log?
    debug : bool
        Do you want to turn on SQL echoing? Use with caution. Engine is not
        cached in this case!

    Yields
    ------
    Session
        The created session.

    """
    global cached_engine
    if cached_engine is None:
        cached_engine = new_engine()
        # log.info("Don't yet have engine... creating default from ignition",
        #          engine=id(cached_engine))

    session = new_session(cached_engine)
    try:
        yield session
        session.commit()
    except BaseException as exc:
        session.rollback()
        print exc
        raise
    finally:
        session.close()
