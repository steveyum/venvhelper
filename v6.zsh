#!/usr/bin/env zsh

# This is a rewrite of my useful venv which replicates
# the functions of virtualenvwrapper for Python 2.x
# Since Python 3.x now has virtualenv functions built-in
# you no longer need virtualenv + wrapper combo... all you
# need is the wrapper.
# With this in mind, I'd created venvwrapper script and it
# worked very well. But after Apple defaulted to zsh from bash,
# I saw that my script had many errors and shortcomings.
# To address that and the unwieldy syntax (mkvenv, lsvenvs, etc)
# I decided to rewrite the whole fucking thing

export V6_SYS_PYTHON="$(command \which python3)"
export V6_SYS_SITEPKGS=$($V6_SYS_PYTHON -c "import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())")

export VARS_USED=(VENV_MY_VENV_NAME VENV_MY_PROJECT VENV_MY_VENV VENV_MY_SITEPKGS)

# There's 3 possible outcome from this function
# 1. envar HOME -> returns $HOME
# 2. envar HOME /home/jack:
#       - if $HOME == '/home/jill' it will be untouched
#       - if $HOME == '' it will be set to /home/jack
function envar () {
    local envar="$1"
    local whatItContains="${(P)envar}"

    if [[ $# -eq 1 ]] || [ -n "$whatItContains" ];
    then
        echo $whatItContains
        return
    fi
    local desiredValue="$2"
    if [ -z $whatItContains ];
    then
        eval "export $envar=$desiredValue"
        echo $desiredValue
        return
    fi
}

declare -A VENV_DIRS

VENV_DIRS["VENV_HOME_ROOT"]="$HOME/.venv"
VENV_DIRS["VENV_PROJECT_HOME"]="$VENV_HOME_ROOT/projects"
_check_venv_dir "VENV_VENV_HOME"    "$VENV_HOME_ROOT/venvs"
_check_venv_dir "VENV_HOOK_HOME"    "$VENV_HOME_ROOT/hooks"

function endir() {

}

function _check_venv_dir () {
    local env_name="$1"                 # example: env_name="VENV_HOME_ROOT"
    local def_value="$2"                # example: def_value="$HOME/.venv"
    local env_content="${(P)env_name}"  # env_content="$VENV_HOME_ROOT"

    if [ -z "$env_content" ]
    then
        eval "export $env_name=$def_value"
    fi
    
    local env_content="${(P)env_name}"

    if [ ! -d "$env_content" ]
    then
        echo "creating $env_content..."
        mkdir -p $env_content
    fi
}
# so, we need to define those directories and create them
# or inherit them from the .bashrc whence they came

_check_venv_dir "VENV_HOME_ROOT"    "$HOME/.venv"
_check_venv_dir "VENV_PROJECT_HOME" "$VENV_HOME_ROOT/projects"
_check_venv_dir "VENV_VENV_HOME"    "$VENV_HOME_ROOT/venvs"
_check_venv_dir "VENV_HOOK_HOME"    "$VENV_HOME_ROOT/hooks"