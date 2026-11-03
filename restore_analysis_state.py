"""Restore only verified analysis-state fields, never track records or music files."""
import argparse
import collections
import datetime
import hashlib
import json
import subprocess
import os
from pathlib import Path


ROOT = Path(os.environ.get("REKORDBOX_ROOT", Path.home() / "AppData/Roaming/Pioneer/rekordbox"))
RECOVERY = Path(os.environ.get("REKORDBOX_RECOVERY", Path.home() / "rekordbox-recovery"))
KEY = os.environ.get("REKORDBOX_DB_KEY", "")
FIELDS = {"Analysed", "ContentLink"}
ALLOWED_DIFFERENCES = FIELDS | {"updated_at", "rb_local_usn"}


def connect(path, writable=False):
    c = sqlite.connect(path.as_uri() + ("?mode=rw" if writable else "?mode=ro"), uri=True)
    c.execute("PRAGMA key='" + KEY + "'")
    if not writable:
        c.execute("PRAGMA query_only=ON")
    c.row_factory = sqlite.Row
    return c


def tables_digest(c):
    result = {}
    for row in c.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
        name = row[0]
        rows = []
        for record in c.execute('SELECT * FROM "' + name.replace('"', '""') + '"'):
            item = dict(record)
            if name == "djmdContent":
                for field in FIELDS:
                    item.pop(field)
            rows.append(json.dumps(item, sort_keys=True, default=str))
        result[name] = hashlib.sha256("\n".join(sorted(rows)).encode()).hexdigest()
    return result


def assert_closed():
    check = subprocess.run(
        [os.environ.get("REKORDBOX_POWERSHELL", "powershell.exe"),
         "-NoProfile", "-NonInteractive", "-Command",
         "if(Get-Process rekordbox -ErrorAction SilentlyContinue){exit 2}else{exit 0}"],
        capture_output=True,
    )
    if check.returncode:
        raise RuntimeError("rekordbox must be closed")


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog="Environment: REKORDBOX_DB_KEY (required), REKORDBOX_ROOT (database directory), REKORDBOX_RECOVERY (backup directory), REKORDBOX_EXPECTED_CANDIDATES (required for --apply), REKORDBOX_POWERSHELL (default powershell.exe).")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    global sqlite
    from sqlcipher3 import dbapi2 as sqlite
    if not KEY:
        parser.error("set REKORDBOX_DB_KEY")
    assert_closed()
    old = connect(ROOT / "master.backup2.db")
    source = connect(ROOT / "master.db")
    old_rows = {r["ID"]: dict(r) for r in old.execute("SELECT * FROM djmdContent")}
    current = {r["ID"]: dict(r) for r in source.execute("SELECT * FROM djmdContent")}
    candidates = {}
    for ident, row in current.items():
        previous = old_rows.get(ident)
        if not previous or row["FolderPath"] != previous["FolderPath"]:
            continue
        if previous["Analysed"] != 105 or row["Analysed"] != 104:
            continue
        differences = {key for key in row if row[key] != previous[key]}
        if not differences <= ALLOWED_DIFFERENCES:
            continue
        candidates[ident] = previous
    counts = collections.Counter()
    rejected = set()
    evidence = []
    for file_row in old.execute("SELECT * FROM contentFile"):
        ident = file_row["ContentID"]
        if ident not in candidates or not file_row["Path"].upper().endswith((".DAT", ".EXT", ".2EX")):
            continue
        path = ROOT / "share" / file_row["Path"].lstrip("/")
        if not path.is_file():
            rejected.add(ident)
            continue
        raw = path.read_bytes()
        digest = hashlib.md5(raw).hexdigest()
        if raw[:4] != b"PMAI" or digest != file_row["Hash"]:
            rejected.add(ident)
            continue
        counts[ident] += 1
        evidence.append({"track_id": ident, "path": str(path), "md5": digest})
    approved = {
        ident: previous for ident, previous in candidates.items()
        if ident not in rejected and counts[ident] == 3
    }
    print(json.dumps({"current_tracks": len(current), "verified_candidates": len(approved),
                      "verified_analysis_files": len(evidence), "rejected": len(rejected)}), flush=True)
    if not args.apply:
        return
    expected = os.environ.get("REKORDBOX_EXPECTED_CANDIDATES")
    if expected is None:
        parser.error("set REKORDBOX_EXPECTED_CANDIDATES to the reviewed dry-run count")
    assert len(approved) == int(expected), "Candidate population changed; review required"
    assert_closed()
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    destination = RECOVERY / stamp
    destination.mkdir(parents=True, exist_ok=False)
    backup = sqlite.connect(str(destination / "before.db"))
    backup.execute("PRAGMA key='" + KEY + "'")
    source.backup(backup)
    assert backup.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    before_digest = tables_digest(source)
    before_schema = list(source.execute("SELECT type,name,sql FROM sqlite_master ORDER BY type,name"))
    records = [
        {"id": ident, "title": current[ident]["Title"],
         "before": {field: current[ident][field] for field in FIELDS},
         "after": {field: previous[field] for field in FIELDS}}
        for ident, previous in approved.items()
    ]
    (destination / "changes.json").write_text(json.dumps(records, indent=2))
    (destination / "analysis-file-evidence.json").write_text(json.dumps(evidence, indent=2))
    backup.close()
    source.close()
    old.close()
    assert_closed()
    c = connect(ROOT / "master.db", writable=True)
    c.execute("BEGIN IMMEDIATE")
    try:
        assert tables_digest(c) == before_digest, "Database changed during preparation"
        for record in records:
            result = c.execute(
                "UPDATE djmdContent SET Analysed=?, ContentLink=? "
                "WHERE ID=? AND Analysed=? AND ContentLink=?",
                (record["after"]["Analysed"], record["after"]["ContentLink"],
                 record["id"], record["before"]["Analysed"], record["before"]["ContentLink"]),
            )
            assert result.rowcount == 1, "Track state changed"
        assert tables_digest(c) == before_digest, "Unrelated data changed"
        assert [tuple(r) for r in c.execute("SELECT type,name,sql FROM sqlite_master ORDER BY type,name")] == [tuple(r) for r in before_schema]
        assert c.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        c.commit()
    except BaseException:
        c.rollback()
        raise
    assert tables_digest(c) == before_digest
    assert c.execute("SELECT count(*) FROM djmdContent").fetchone()[0] == len(current)
    final_states = {r["ID"]: dict(r) for r in c.execute("SELECT ID,Analysed,ContentLink FROM djmdContent")}
    for record in records:
        assert all(final_states[record["id"]][field] == record["after"][field] for field in FIELDS)
    c.close()
    print(json.dumps({"repaired_tracks": len(records), "rollback_database": str(destination / "before.db"),
                      "all_other_table_data_unchanged": True, "integrity_check": "ok"}), flush=True)


if __name__ == "__main__":
    main()
