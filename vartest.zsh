#!/usr/local/bin/zsh

DIRS=( 'V6_ROOT' 'V6_PROJECTS' 'V6_VENVS' 'V6_HOOKS' )
DEFAULTS=( '$HOME/.venv' '$V6_ROOT/projects' '$V6_ROOT/venvs' '$V6_ROOT/hooks' )
VALS=(
V6_ROOT      $HOME/.venv
V6_PROJECTS  $V6_ROOT/projects
V6_VENVS     $V6_ROOT/venvs
V6_HOOKS     $V6_ROOT/hooks
)
for k v in ${(kv)VALS[@]}; do
    printf "%s \t-> %s\n" $k $(printf "%s" $v)
done



