#!/usr/local/bin/zsh

# A rewrite of my own venvwrapper for the Z Shell
# I didn't realize how much I use this script.
# Venvwrapper is totally customizable replacement
# for virtualenvwrapper scripts, plus the ability to
# specify where all your projects will live.

# Venvwrapper is a light yet full version of the
# virtualenv + virtualenvwrapper scripts but written
# for Python 3.x which comes with basic virtualenv
# built-in, rather included in default basic pkgs.

# 'Venv' as it's called in Python 3.x, is full
# featured and lightning fast, but its usage syntax
# is obtuse. It also lacks the helper scripts that
# help in creating/removing and managing virtual
# environments.

# --------------------------------------------------------
# Zero: Get the full path to system's global Python3
# and the path to the global site-packages directory
# Note: this should be inherited from .bashrc, otherwise
# it will just grab the virtualenv's Python
# --------------------------------------------------------

export VENV_SYSTEM_PYTHON="$(command \which python3)"
export VENV_SYSTEM_SITEPKGS=$($VENV_SYSTEM_PYTHON -c "import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())")

VARS_USED="
VENV_MY_VENV_NAME
VENV_MY_PROJECT
VENV_MY_VENV
VENV_MY_SITEPKGS"

# What shell are we running this on?
# I came up with a one-liner that figures out what shell is
# responsible for running a command or script
# The same one-liner works both in CLI env or inside a script
# If it's run inside the script, it basically tells you what's
# after the shebang (#!). At command line, it will tell you the
# most recent process to your input, which is the shell
function whatshell () {
    shell=$(ps -o args= -p "$$" | awk '{print $1}' | egrep -m 1 -o '\w{0,5}sh')
    echo $shell
}

# function _check_venv_dir () {

# # what's tricky here is that we need something like ${$env_var}
# # in bash, you'd use ${!env_var}
# # in zsh, you would use ${(P)env_var}
#     local env="$1"
#     local var="$2"

#     # is the ENV variable empty?
#     echo "env = $env"
#     echo "var = $var"
#     env_value="${(P)env}"
#     if [ -z "$env_value" ]
#     then
#         #export $env_name=$var
#         eval "export $env=$var"
#     fi
#     if [ ! -d "${(P)}" ]
#     then
#         echo "mkdir -p ${(P)var}"
#     fi
# }

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

function mkvenv {
    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT_HOME/$venv_name"
    local venv_fullpath="$VENV_VENV_HOME/$venv_name"

    if [ -z "$venv_name" ]
    then
        echo "ERROR: Please specify a name for the virtual environment you want to create!" >&2
        return 1
    fi

    if [ -d "$VENV_PROJECT_HOME/$venv_name" ]
    then
        echo "ERROR: Project named '$venv_name' already exists!" >&2
        return 1
    fi

    echo "Creating virtual environment for project: $venv_name ..."
    $VENV_SYSTEM_PYTHON -m venv $venv_fullpath && mkdir $project_fullpath
    if [ $? -ne 0 ]
    then
        echo "ERROR: Unable to create virtual environment" >&2
        return 1
    fi
    _venv_run_hook "post_make" "$venv_name"
    usevenv $venv_name
}

function usevenv {

    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT_HOME/$venv_name"
    local venv_fullpath="$VENV_VENV_HOME/$venv_name"

    # first, check if venv is already active...
    # then deactivate it before going further.
    if [ -n $VIRTUAL_ENV ]
    then
        # is there a deactivate function we could use?
        typeset -f deactivate | grep 'typeset postdeactivate_hook' >/dev/null 2>&1
        # if it's our modded 'deactive' function use it
        if [ $? -eq 0 ]
        then
            echo -n "Deactivating already active virtualenv: "
            echo $(basename $VIRTUAL_ENV)
            deactivate
            unset -f deactivate >/dev/null 2>&1
        fi
    fi

    # check for stupid user input or other shit
    # if fullpath is not a directory or doesn't exist, it
    # is not a venv
    if [ ! -d "$venv_fullpath" ]
    then
        echo "ERROR: Project named '$venv_name' does not exist!" >&2
        return 1
    fi
    # is there an activate script for this venv?
    local activate="$venv_fullpath/bin/activate"
    if [ ! -f "$activate" ]
    then
        echo "ERROR: Environment '$venv_fullpath' does not contain an activate script." >&2
        return 1
    fi

    # activate the venv and set env var VENV_VENV_NAME
    # which can be used for scripting or such
    _venv_run_hook "pre_activate" "$venv_name"
    source "$activate"

    export VENV_MY_SITEPKGS="$(python3 -c 'import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())')"
    export VENV_MY_PROJECT=$project_fullpath
    export VENV_MY_VENV=$venv_fullpath

    # save the current directory
    #echo "pushing current dir into stack"
    pushd . >/dev/null
    _venv_set_cd

    # save original 'deactivate' as venv_deactivate
    local venv_deactivate="$(typeset -f deactivate | sed 's/^deactivate/venv_deactivate/g')"
    eval "$venv_deactivate"

    unset -f deactivate >/dev/null 2>&1
    # Replace the deactivate() function with a wrapper.
    eval 'deactivate () {
        typeset postdeactivate_hook
        typeset old_env

        # Call the local hook before the global so we can undo
        # any settings made by the local postactivate first.
        _venv_run_hook "pre_deactivate"

        postdeactivate_hook="$VENV_HOOK_HOME/postdeactivate"
        old_env=$(basename "$VIRTUAL_ENV")

        # Call the original function.
        venv_deactivate $1

        _venv_run_hook "post_deactivate" "$old_env"

        _venv_set_cd

        if [ ! "$1" = "nondestructive" ]
        then
            # Remove these two functions always


            # !! changed the following two lines for ZSH!!!!
            _venv_nuke_funcs virtualenv_deactivate deactivate cd
            _venv_nuke_vars $(echo "$VARS_USED")
            

            # pop dir stack if something is in there

            # !! changed the if block for ZSH!!!
            #echo "resetting directory..."
            if [[ $(dirs -v | wc -l) -gt 1 ]]
            then
                popd >/dev/null
            else
                cd
            fi
        fi
    }'
    cd
    _venv_run_hook "post_activate" "$venv_name"
    return 0
}

function lsvenvs {
    if [ ! -d $VENV_VENV_HOME ] && [ ! -d $VENV_PROJECT_HOME ]
    then
        echo "ERROR: You do not have any virtual environments!" >&2
        return 1
    fi
    for venv in "$VENV_VENV_HOME"/*
    do
        venv_name=$(basename $venv)
        if [ -d $VENV_VENV_HOME/$venv_name ] && [ -d $VENV_PROJECT_HOME/$venv_name ]
        then
            echo $venv_name
        fi
    done
}

function cdvenv {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $VENV_MY_VENV
    fi
}

function cdproject {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $VENV_MY_PROJECT
    fi
}

function cdsitepkgs {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $VENV_MY_SITEPKGS
    else
        cd $VENV_SYSTEM_SITEPKGS
    fi
}

function rmvenv {
    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT_HOME/$venv_name"
    local venv_fullpath="$VENV_VENV_HOME/$venv_name"

    if [ -z $venv_name ]
    then
        echo "ERROR: Please specify the name of the virtual environment you want to remove!" >&2
        return 1
    fi
    # don't remove the venv we're in
    if [ "$VIRTUAL_ENV" = "$venv_fullpath" ]
    then
        echo "ERROR: Cannot remove '$env_name'. Deactivate it first!" >&2
        return 1
    fi

    if [ -d $project_fullpath ] && [ -d $venv_fullpath ]
    then
        echo -n "Removing project '$venv_name'..."
        rm -rf $project_fullpath
        rm -rf $venv_fullpath
        echo "done!"
    else
        echo "ERROR: No such project/environment!" >&2
        return 1
    fi
}

#function su { p=("$@"); for i in ${p[@]}; do echo $i; done }

function _venv_nuke_funcs {
    local targets=("$@")

    for t in ${targets[@]}
    do
        #echo "nuking func: $t"
        typeset -f $t >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            unset -f $t >/dev/null 2>&1
        fi
    done
}

function _venv_nuke_vars {
    local targets=("$@")

    for t in ${targets[@]}
    do
        #echo "nuking var: $t"
        unset $t >/dev/null 2>&1
    done
}
function _venv_set_cd {

    # first clear any cd function, if there is one already defined
    typeset -f cd >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        unset -f cd >/dev/null 2>&1
    fi
    # auto cd'ing into the project is default 
    # if you set VENV_CD_TO_PROJECT to 'false' in .bashrc
    # cd will function as normal
    if [ -n "$VIRTUAL_ENV" ] && [ "$VENV_CD_TO_PROJECT" != "false" ]
    then
        function cd {
            if (( $# == 0 ))
            then
                builtin cd $VENV_MY_PROJECT
            else
                builtin cd "$@"
            fi
        }
    fi
}
function _venv_run_hook {
    local hook_script="$1"
    local venv_name="$2"
    local venv_hook="$VENV_HOOK_HOME/$1"

    #echo "venv_hook = $venv_hook"
    if [ ! -f $venv_hook ]
    then
        return 1
    fi
    #echo "venv_name = $venv_name"
    if [ -n $venv_name ]
    then
        source $venv_hook $venv_name
    else
        source $venv_hook
    fi
}