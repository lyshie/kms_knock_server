CREATE TABLE knock (
    id       INTEGER PRIMARY KEY,
    lasttime INTEGER,
    ip       TEXT,
    username TEXT,
    host     TEXT,
    count    INTEGER default 0,
    UNIQUE (ip, username, host)
);
