#!/usr/bin/env bash
set -euo pipefail

# --- helpers ---
usage() {
  echo "Usage: $(basename "$0") <log-directory> [output-dir]" 1>&2
  exit 1
}

err() {
  echo "ERROR: $*" 1>&2
  exit 1
}

# --- args & validation ---
[[ $# -ge 1 ]] || usage
LOG_DIR="$1"
[[ -d "$LOG_DIR" ]] || err "Directory not found: $LOG_DIR"

# Default destination lives OUTSIDE the input dir to avoid self-archiving loops
DEFAULT_OUT="$(dirname "$LOG_DIR")/log-archives"
OUT_DIR="${2:-$DEFAULT_OUT}"
mkdir -p "$OUT_DIR"

# Permission sanity check (archiving /var/log usually needs root)
[[ -r "$LOG_DIR" ]] || err "Insufficient permissions to read $LOG_DIR (try: sudo $0 $LOG_DIR)"

# --- archive file name ---
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME="logs_archive_${TS}.tar.gz"
ARCHIVE_PATH="${OUT_DIR}/${ARCHIVE_NAME}"

# --- create tar.gz ---
# Use -C to avoid storing absolute paths; archive the whole LOG_DIR as a folder.
tar -czf "$ARCHIVE_PATH" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")"

# --- logging the run ---
LOGFILE="${OUT_DIR}/log-archive.log"
SIZE_HUMAN="$(du -h "$ARCHIVE_PATH" | awk '{print $1}')"

DATE_HUMAN="$(date '+%Y-%m-%d %H:%M:%S')"
echo "${DATE_HUMAN} | ${TS} archived '${LOG_DIR}' -> '${ARCHIVE_PATH}' (${SIZE_HUMAN})" >>"$LOGFILE"

# --- output ---
echo "Archive created: ${ARCHIVE_PATH} (${SIZE_HUMAN})"
echo "Run logged to:  ${LOGFILE}"
