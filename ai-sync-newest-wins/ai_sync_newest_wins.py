"""Run ai-sync pull and push so that the newest copy of each file wins.

ai-sync alone does a 3-way merge with git: when both Macs changed a file since
their last sync, `ai-sync pull` keeps the local copy and the next push overwrites
the other Mac's copy, so the Mac that syncs last wins. git does not store file
modification times, so this wrapper keeps them in mtimes.json at the root of the
sync repo (outside the claude/ folder that ai-sync manages):

1. Fetch, and note which files the other Mac changed and which files this Mac
   deleted since the last sync.
2. `ai-sync pull`. For every file it reports as a conflict, compare this Mac's
   modification time with the one the other Mac recorded in mtimes.json, and
   copy the remote version over the local one when the remote is newer.
3. Delete again the files this Mac had deleted. `ai-sync pull` restores every
   repo file that is missing locally, so without this step a deletion never
   reaches the other Mac.
4. `ai-sync push`, then record the modification time of every synced file in
   mtimes.json and push that as a second commit.
"""

import json
import os
import subprocess
from pathlib import Path

HOME = Path.home()
SYNC_REPO = HOME / ".ai-sync"
REPO_SUBDIR = "claude"
CLAUDE_DIR = HOME / ".claude"
MTIMES_FILE = SYNC_REPO / "mtimes.json"
AI_SYNC = HOME / ".local" / "bin" / "ai-sync"
CONFLICT_PREFIX = "Conflict (keeping local): "
# ai-sync stores these files with the home folder replaced by {{HOME}}.
PATH_REWRITE_FILES = {"settings.json", "installed_plugins.json", "known_marketplaces.json"}
HOME_TOKEN = b"{{HOME}}"


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(SYNC_REPO), *args], capture_output=True, text=True
    )
    assert result.returncode == 0, (
        f"git {' '.join(args)} exited {result.returncode}: {result.stderr.strip()}"
    )
    return result.stdout


def strip_subdir(repo_paths: str) -> set[str]:
    prefix = f"{REPO_SUBDIR}/"
    return {p.removeprefix(prefix) for p in repo_paths.split("\0") if p}


def files_in_commit(ref: str) -> set[str]:
    return strip_subdir(git("ls-tree", "-r", "-z", "--name-only", ref, "--", REPO_SUBDIR))


def files_changed_between(ref_a: str, ref_b: str) -> set[str]:
    return strip_subdir(git("diff", "-z", "--name-only", ref_a, ref_b, "--", REPO_SUBDIR))


def run_ai_sync(command: str) -> str:
    result = subprocess.run(
        [str(AI_SYNC), "--no-update-check", command, "-v"],
        capture_output=True,
        text=True,
        env={**os.environ, "NO_COLOR": "1"},
    )
    output = result.stdout + result.stderr
    print(output)
    assert result.returncode == 0, f"ai-sync {command} exited {result.returncode}:\n{output}"
    return output


def conflicts_in(pull_output: str) -> set[str]:
    return {
        line.split(CONFLICT_PREFIX, 1)[1].strip()
        for line in pull_output.splitlines()
        if CONFLICT_PREFIX in line
    }


def read_recorded_mtimes() -> dict[str, float]:
    if not MTIMES_FILE.exists():
        return {}
    return json.loads(MTIMES_FILE.read_text())


def take_remote_copy(relative_path: str, remote_mtime: float) -> None:
    content = (SYNC_REPO / REPO_SUBDIR / relative_path).read_bytes()
    if Path(relative_path).name in PATH_REWRITE_FILES:
        content = content.replace(HOME_TOKEN, str(HOME).encode())
    local_file = CLAUDE_DIR / relative_path
    local_file.write_bytes(content)
    os.utime(local_file, (remote_mtime, remote_mtime))


def resolve_conflicts(conflicts: set[str], recorded: dict[str, float]) -> set[str]:
    """Copy the remote version over each conflict whose remote copy is newer."""
    remote_won = set()
    for relative_path in sorted(conflicts):
        local_mtime = (CLAUDE_DIR / relative_path).stat().st_mtime
        remote_mtime = recorded.get(relative_path, 0.0)
        if remote_mtime > local_mtime:
            take_remote_copy(relative_path, remote_mtime)
            remote_won.add(relative_path)
            print(f"Newer on the other Mac, took remote copy: {relative_path}")
        else:
            print(f"Newer on this Mac, kept local copy: {relative_path}")
    return remote_won


def copy_recorded_mtimes(paths: set[str], recorded: dict[str, float]) -> None:
    """Give files that ai-sync just wrote the other Mac's modification time.

    Without this they would carry the time of the pull, and that time would
    then win against a genuinely newer edit on the other Mac.
    """
    for relative_path in paths:
        local_file = CLAUDE_DIR / relative_path
        if local_file.exists() and relative_path in recorded:
            os.utime(local_file, (recorded[relative_path], recorded[relative_path]))


def record_mtimes() -> None:
    # The repo can hold files outside ai-sync's allowlist (left by older
    # versions); ai-sync never copies those to ~/.claude, so they are skipped.
    local_files = [CLAUDE_DIR / p for p in files_in_commit("HEAD")]
    mtimes = {
        str(f.relative_to(CLAUDE_DIR)): f.stat().st_mtime for f in local_files if f.exists()
    }
    MTIMES_FILE.write_text(json.dumps(mtimes, indent=1, sort_keys=True) + "\n")
    if git("status", "--porcelain", "--", MTIMES_FILE.name):
        git("add", MTIMES_FILE.name)
        git("commit", "-q", "-m", "sync: record file modification times")
        git("push", "-q", "origin", "main")


def main() -> None:
    assert AI_SYNC.exists(), f"ai-sync not found at {AI_SYNC}"
    assert (SYNC_REPO / ".git").is_dir(), f"no sync repo at {SYNC_REPO}"

    git("fetch", "-q", "origin")
    changed_remotely = files_changed_between("HEAD", "origin/main")
    deleted_here = {
        relative_path
        for relative_path in files_in_commit("HEAD")
        if not (CLAUDE_DIR / relative_path).exists()
    } - changed_remotely

    pull_output = run_ai_sync("pull")
    recorded = read_recorded_mtimes()
    conflicts = conflicts_in(pull_output)
    remote_won = resolve_conflicts(conflicts, recorded)
    copy_recorded_mtimes((changed_remotely - conflicts) | remote_won, recorded)

    for relative_path in sorted(deleted_here):
        (CLAUDE_DIR / relative_path).unlink(missing_ok=True)
    print(f"Kept {len(deleted_here)} deletions made on this Mac")

    run_ai_sync("push")
    record_mtimes()
    print(
        f"Done: {len(changed_remotely)} files changed on the other Mac, "
        f"{len(conflicts)} conflicts ({len(remote_won)} took the remote copy)"
    )


if __name__ == "__main__":
    main()
