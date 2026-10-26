-- cue, run a program on many inputs as one Slurm array job.
-- Deployed clone at /groups/kemi/liasi/share/cue, this file at
-- /groups/kemi/liasi/share/modulefiles/cue.lua. Users load it with
--   module use /groups/kemi/liasi/share/modulefiles
--   module load cue
help([[
cue submits one Slurm array job per template and input list.

  cue orca *.inp            submit
  cue list                  templates and where they come from
  cue show orca             print a template
  cue init orca             copy a template to ~/.config/cue/templates
  cue completion --install  bash completion for this user
]])
whatis("Name: cue")
whatis("Description: run a program on many inputs as one Slurm array job")

local home = "/groups/kemi/liasi/share/cue"
setenv("CUE_HOME", home)
prepend_path("PATH", pathJoin(home, "bin"))
