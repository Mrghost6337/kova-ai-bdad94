import os
from collections.abc import Iterator

from psycopg import Connection
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

_pool: ConnectionPool | None = None


def connection_pool() -> ConnectionPool:
    global _pool
    if _pool is None:
        database_url = os.environ["TENX_DATABASE_URL"]
        _pool = ConnectionPool(
            conninfo=database_url,
            min_size=1,
            max_size=4,
            timeout=5,
            max_lifetime=300,
            kwargs={"connect_timeout": 4, "row_factory": dict_row},
            check=ConnectionPool.check_connection,
            open=True,
        )
    return _pool


def database_connection() -> Iterator[Connection]:
    with connection_pool().connection(timeout=5) as connection:
        yield connection
