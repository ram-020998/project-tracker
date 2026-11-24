"""55-11 §3 set-up (L-125): copy genesis.db and memory.db with SQLite's ONLINE BACKUP (never a file copy), then check
each copy's integrity, schema version and row counts against the source. The source is opened read-only (mode=ro, so
it still sees the WAL's commits). Prints counts only, never row content (D19)."""
import sqlite3
import sys
from pathlib import Path

SRC = Path("/Users/ramaswamy.u/.genesis")
DST = Path(sys.argv[1])


def backup(name: str) -> None:
    src = sqlite3.connect(f"file:{SRC / name}?mode=ro", uri=True, timeout=30)
    dst = sqlite3.connect(DST / name)
    src.backup(dst)
    dst.close()
    chk = sqlite3.connect(DST / name)
    integ = chk.execute("PRAGMA integrity_check").fetchone()[0]
    tables = [r[0] for r in chk.execute("SELECT name FROM sqlite_master WHERE type='table'")]
    ver = None
    if "schema_migrations" in tables:
        ver = chk.execute("SELECT MAX(version) FROM schema_migrations").fetchone()[0]
    counts = {}
    for t in ("runs", "run_events", "memories", "chat_sessions", "scheduled_jobs"):
        if t in tables:
            a = src.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            b = chk.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            counts[t] = (a, b)
    print(f"{name}: integrity={integ} schema_version={ver} counts(src,copy)={counts}")
    chk.close()
    src.close()


for n in ("genesis.db", "memory.db"):
    backup(n)
