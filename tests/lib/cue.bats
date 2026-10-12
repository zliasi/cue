#!/usr/bin/env bats
# Tests for lib/cue.sh with fake Slurm variables and a scratch root under
# the test temp dir. Job scripts run in a child bash so traps and cd stay
# isolated from the test process.
#
# Lines passed to job are script text for the child, so they must not expand
# here.
# shellcheck disable=SC2016

setup() {
  LIB="$BATS_TEST_DIRNAME/../../lib/cue.sh"
  cd "$BATS_TEST_TMPDIR" || return 1
  mkdir in
  printf '! HF\n' >in/h2o.inp
  printf '! HF\n' >in/co2.inp
  printf 'in/h2o.inp\nin/co2.inp\nin/missing.inp\n' >list.txt
  export SLURM_JOB_ID=4242 SLURM_ARRAY_JOB_ID=4200 SLURM_ARRAY_TASK_ID=0
  export CUE_SCRATCH_ROOT="$BATS_TEST_TMPDIR/scratch"
  export LOADEDMODULES="intel/2024:kemi"
  # shellcheck disable=SC1090
  source "$LIB"
}

# Write a job script that sources the lib and runs BODY after cue_start.
job() {
  {
    printf '#!/usr/bin/env bash\nset -euo pipefail\nsource "%s"\n' "$LIB"
    printf 'cue_start list.txt out\n'
    printf '%s\n' "$@"
  } >job.sh
}

@test "cue_line picks line task+1" {
  SLURM_ARRAY_TASK_ID=1 run cue_line list.txt
  [ "$status" -eq 0 ]
  [ "$output" = "in/co2.inp" ]
}

@test "cue_line fails without a task id" {
  unset SLURM_ARRAY_TASK_ID
  run cue_line list.txt
  [ "$status" -eq 1 ]
  [[ $output == *"SLURM_ARRAY_TASK_ID"* ]]
}

@test "cue_line fails past the last line" {
  SLURM_ARRAY_TASK_ID=3 run cue_line list.txt
  [ "$status" -eq 1 ]
  [[ $output == *"no line for task 3"* ]]
}

@test "cue_line fails on an unreadable manifest" {
  run cue_line nope.txt
  [ "$status" -eq 1 ]
  [[ $output == *"cannot read manifest nope.txt"* ]]
}

@test "cue_start stages the input and prints the header" {
  job 'printf "%s\n" "$PWD" "$CUE_INPUT" "$CUE_STEM" "$CUE_OUTDIR"'
  run bash job.sh
  [ "$status" -eq 0 ]
  scratch="$CUE_SCRATCH_ROOT/4242/0"
  [ -f "$scratch/h2o.inp" ]
  [ -d out ]
  [[ $output == *"cue: job 4200_0 on"* ]]
  [[ $output == *"cue: modules intel/2024:kemi"* ]]
  [[ $output == *"cue: end status 0"* ]]
  lines_after_header=$(printf '%s\n' "$output" | grep -v '^cue:')
  [ "$lines_after_header" = "$scratch
$scratch/h2o.inp
h2o
$BATS_TEST_TMPDIR/out" ]
}

@test "cue_start fails on a missing input" {
  job 'printf "not reached\n"'
  SLURM_ARRAY_TASK_ID=2 run bash job.sh
  [ "$status" -eq 1 ]
  [[ $output == *"cue: input not found: in/missing.inp"* ]]
  [[ $output != *"not reached"* ]]
}

@test "cue_retrieve copies only the named globs" {
  job 'printf "a\n" > h2o.gbw' 'printf "b\n" > h2o.tmp' 'cue_retrieve "*.gbw"'
  run bash job.sh
  [ "$status" -eq 0 ]
  [ "$(cat out/h2o.gbw)" = "a" ]
  [ ! -e out/h2o.tmp ]
  [ "$(grep -c 'cue: retrieved h2o.gbw' <<<"$output")" -eq 2 ]
}

@test "cue_run returns the command status and keeps program output clean" {
  job 'cue_run bash -c "echo prog; exit 7" > "$CUE_OUTDIR/$CUE_STEM.out" || printf "status %s\n" "$?"'
  run bash job.sh
  [ "$status" -eq 0 ]
  [[ $output == *"status 7"* ]]
  [ "$(cat out/h2o.out)" = "prog" ]
}

@test "USR1 during cue_run copies partial then final results" {
  job 'cue_retrieve "*.gbw"' \
    'printf "early\n" > h2o.gbw' \
    'cue_run bash -c "sleep 2; printf late\\\\n > h2o.gbw" > "$CUE_OUTDIR/$CUE_STEM.out"' \
    'printf "copy during run: %s\n" "$(cat "$CUE_OUTDIR/h2o.gbw")"'
  bash job.sh >log.txt 2>&1 &
  pid=$!
  sleep 1
  kill -USR1 "$pid"
  wait "$pid"
  run cat log.txt
  [[ $output == *"cue: time limit near, retrieving partial results"* ]]
  [[ $output == *"copy during run: early"* ]]
  [ "$(cat out/h2o.gbw)" = "late" ]
  [ ! -s out/h2o.out ]
}

@test "EXIT trap retrieves and preserves a failure status" {
  job 'cue_retrieve "*.gbw"' 'printf "partial\n" > h2o.gbw' 'cue_run false' 'printf "not reached\n"'
  run bash job.sh
  [ "$status" -eq 1 ]
  [ "$(cat out/h2o.gbw)" = "partial" ]
  [[ $output == *"cue: end status 1"* ]]
  [[ $output != *"not reached"* ]]
}
