#!/usr/bin/env bash
# Job-side library for cue templates.
#
# Source it from an sbatch script that runs as one task of a Slurm array
# submitted with --signal=B:USR1@<seconds>. The caller sets its own shell
# options, nothing here changes them.
#
# Public functions: cue_line, cue_start, cue_run, cue_retrieve.
# Reads: SLURM_JOB_ID, SLURM_ARRAY_JOB_ID, SLURM_ARRAY_TASK_ID, LOADEDMODULES,
# CUE_SCRATCH_ROOT (default /scratch).
# Exports: CUE_INPUT, CUE_STEM, CUE_OUTDIR, CUE_SCRATCH.
# Needs bash 4.4 or newer and coreutils. Scratch is never removed here, the
# site epilog deletes /scratch/$SLURM_JOB_ID after the job.

CUE__RETRIEVE=()
CUE__SIGNALED=0
CUE__LOG=1

cue__err() {
  # Print a diagnostic on stderr. Callers return 1 themselves.
  printf 'cue: %s\n' "$*" >&2
}

cue__log() {
  # Print a progress line on the job log. cue_start saves the script stdout
  # in CUE__LOG, so lines from the traps never land in a redirected program
  # output such as 'cue_run prog > file'.
  printf 'cue: %s\n' "$*" >&"$CUE__LOG"
}

cue_line() {
  # Print the manifest line that belongs to this array task.
  # Usage: cue_line MANIFEST
  # Task N reads line N+1, arrays start at 0. Fails when the task id is
  # missing or not a number, the file is unreadable, or the line is empty.
  local manifest task line
  if [[ $# -ne 1 ]]; then
    cue__err "usage: cue_line MANIFEST"
    return 1
  fi
  manifest=$1
  task=${SLURM_ARRAY_TASK_ID:-}
  if [[ ! $task =~ ^[0-9]+$ ]]; then
    cue__err "SLURM_ARRAY_TASK_ID is not a number, cue runs array jobs only"
    return 1
  fi
  if [[ ! -r $manifest ]]; then
    cue__err "cannot read manifest $manifest"
    return 1
  fi
  line=$(sed -n "$((task + 1))p" -- "$manifest")
  if [[ -z $line ]]; then
    cue__err "manifest $manifest has no line for task $task"
    return 1
  fi
  printf '%s\n' "$line"
}

cue_start() {
  # Stage this array task and arm the copy-back traps.
  # Usage: cue_start MANIFEST OUTDIR
  # Selects the input with cue_line, creates OUTDIR and the scratch
  # directory, copies the input into scratch, changes into scratch, installs
  # the USR1 and EXIT traps, and prints a header.
  # Exports CUE_INPUT (the copy in scratch), CUE_STEM (input basename without
  # its last extension), CUE_OUTDIR (absolute), and CUE_SCRATCH
  # ($CUE_SCRATCH_ROOT/$SLURM_JOB_ID/$SLURM_ARRAY_TASK_ID).
  # Fails when SLURM_JOB_ID is unset, the manifest line is bad, or the input
  # does not exist.
  local manifest outdir source base
  if [[ $# -ne 2 ]]; then
    cue__err "usage: cue_start MANIFEST OUTDIR"
    return 1
  fi
  manifest=$1
  outdir=$2
  if [[ -z ${SLURM_JOB_ID:-} ]]; then
    cue__err "SLURM_JOB_ID is not set, cue_start runs inside a job only"
    return 1
  fi
  source=$(cue_line "$manifest") || return 1
  if [[ ! -f $source ]]; then
    cue__err "input not found: $source"
    return 1
  fi
  source=$(realpath -- "$source")
  base=${source##*/}
  CUE_STEM=${base%.*}
  mkdir -p -- "$outdir"
  CUE_OUTDIR=$(realpath -- "$outdir")
  CUE_SCRATCH="${CUE_SCRATCH_ROOT:-/scratch}/$SLURM_JOB_ID/$SLURM_ARRAY_TASK_ID"
  mkdir -p -- "$CUE_SCRATCH"
  cp -p -- "$source" "$CUE_SCRATCH/$base"
  CUE_INPUT="$CUE_SCRATCH/$base"
  cd -- "$CUE_SCRATCH" || return 1
  export CUE_INPUT CUE_STEM CUE_OUTDIR CUE_SCRATCH
  exec {CUE__LOG}>&1
  CUE__RETRIEVE=()
  CUE__SIGNALED=0
  trap cue__on_usr1 USR1
  trap cue__on_exit EXIT
  cue__header "$source"
}

cue__header() {
  # Print job id, host, time, input, directories, and loaded modules.
  local modules
  modules=${LOADEDMODULES:-}
  cue__log "job ${SLURM_ARRAY_JOB_ID:-$SLURM_JOB_ID}_$SLURM_ARRAY_TASK_ID" \
    "on $(hostname) at $(date '+%Y-%m-%d %H:%M:%S')"
  cue__log "input $1"
  cue__log "scratch $CUE_SCRATCH"
  cue__log "outdir $CUE_OUTDIR"
  cue__log "modules ${modules:-none}"
}

cue_run() {
  # Run CMD in the background and wait for it.
  # Usage: cue_run CMD [ARG...]
  # Returns the exit status of CMD. Redirections on the call apply to CMD.
  # Running in the background lets a trapped USR1 interrupt the wait, so the
  # retrieve handler runs while CMD is still alive.
  local pid status
  if [[ $# -lt 1 ]]; then
    cue__err "usage: cue_run CMD [ARG...]"
    return 1
  fi
  "$@" &
  pid=$!
  status=0
  wait "$pid" || status=$?
  # A trapped signal returns 128+signal from the first wait while CMD still
  # runs, so wait once more for the real status.
  if ((status > 128)) && kill -0 "$pid" 2>/dev/null; then
    status=0
    wait "$pid" || status=$?
  fi
  return "$status"
}

cue_retrieve() {
  # Copy files matching GLOB from the top of scratch to CUE_OUTDIR.
  # Usage: cue_retrieve GLOB [GLOB...]
  # Patterns are basenames, quote them at the call site. Copies run now and
  # again from the USR1 and EXIT traps. Copies overwrite, no match is not an
  # error. Needs cue_start.
  if [[ $# -lt 1 ]]; then
    cue__err "usage: cue_retrieve GLOB [GLOB...]"
    return 1
  fi
  if [[ -z ${CUE_SCRATCH:-} ]]; then
    cue__err "cue_retrieve needs cue_start first"
    return 1
  fi
  CUE__RETRIEVE+=("$@")
  cue__collect "$@"
}

cue__collect() {
  # Copy the files in scratch that match each pattern, one log line per file.
  local pattern file
  for pattern in "$@"; do
    while IFS= read -r -d '' file; do
      if cp -p -- "$file" "$CUE_OUTDIR/"; then
        cue__log "retrieved ${file##*/}"
      else
        cue__err "failed to retrieve ${file##*/}"
      fi
    done < <(find "$CUE_SCRATCH" -maxdepth 1 -type f -name "$pattern" -print0)
  done
}

cue__on_usr1() {
  # Slurm sends USR1 shortly before the time limit. Copy what exists once,
  # the program keeps running until the limit.
  if ((CUE__SIGNALED)); then
    return 0
  fi
  CUE__SIGNALED=1
  cue__log "time limit near, retrieving partial results"
  cue__collect "${CUE__RETRIEVE[@]}"
}

cue__on_exit() {
  # Final copy-back. Must not call exit, so the script status is preserved.
  local status=$?
  cue__collect "${CUE__RETRIEVE[@]}"
  cue__log "end status $status"
}
