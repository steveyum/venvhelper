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

# -----------------------------------------------------------------------------------------------------------------
# This is a small and tricky function that I find useful.
# SYNTAX: _envar "ENVAR" ["desiredValue"]
#   * the function will assign ENVAR="desiredValue"
#     only if ENVAR is either not set or is empty
#   * if ENVAR is already defined "desiredValue" is ignored!
#   * just calling _envar "ENVAR" will return the value of ENVAR
function _envar () {
    local envar="$1"    # ie, "HOME"
    local whatItContains="${(P)envar}"  # "$HOME"

    if [[ $# -eq 1 ]] || [ -n "$whatItContains" ];
    # no second arg, or env is already defined with non-zero value
    # the just output what the (old) value is 
    then
        echo $whatItContains
        return
    fi
    local desiredValue="$2"
    if [ -z $whatItContains ]; # is $HOME == ''?
    then
        # env is blank so assign it with desiredValue
        eval "export $envar=$desiredValue"
        echo $desiredValue
        return
    fi
}

# - create foundation directories for venv to work
function _endir {
    local dir=$(_envar "$1" "$2")

    echo "checking directory: $dir"
    if [ ! -e $dir ];
    then
        echo "mkdir $dir"
    fi
}
_endir VENV_ROOT     "$HOME/.venv"
_endir VENV_PROJECT "$VENV_ROOT/projects"
_endir VENV_VENV     "$VENV_ROOT/venvs"
_endir VENV_HOOK     "$VENV_ROOT/hooks"
#------------------------------------------------------------------------
VENV_VARS=( VENV_ROOT VENV_PROJECT VENV_VENV VENV_HOOK )

VENV_DIRS['VENV_ROOT']="$HOME/.venv"
VENV_DIRS['VENV_PROJECT']="$VENV_ROOT/projects"
VENV_DIRS['VENV_VENV']="$VENV_ROOT/venvs"
VENV_DIRS['VENV_HOOK']="$VENV_ROOT/hooks"



function checkDirs {
    for e in ( VENV_ROOT VENV_PROJECT VENV_VENV VENV_HOOK )
    do
        d=$VENV_DIRS[$e]
        dir=$(_envar $e $d)
        if [ ! -e $dir ];
        then
            echo "mkdir $dir"
        fi
    done
}
# ------------------------------------------------

function _v6_mk {
    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT/$venv_name"
    local venv_fullpath="$VENV_VENV/$venv_name"

    if [ -z "$venv_name" ]
    then
        echo "ERROR: Please specify a name for the virtual environment you want to create!" >&2
        return 1
    fi

    if [ -d "$VENV_PROJECT/$venv_name" ]
    then
        echo "ERROR: Project named '$venv_name' already exists!" >&2
        return 1
    fi

    echo "Creating virtual environment for project: $venv_name ..."
    $VENV_SYS_PYTHON -m venv $venv_fullpath && mkdir $project_fullpath
    if [ $? -ne 0 ]
    then
        echo "ERROR: Unable to create virtual environment" >&2
        return 1
    fi
    _venv_run_hook "post_make" "$venv_name"
    _v6_use $venv_name
}

function _v6_use {
    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT/$venv_name"
    local venv_fullpath="$VENV_VENV/$venv_name"

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
    # don't just replace  /deactivate/venv_deactivate as that will break many things
    # you just wanna change the first instance of 'deactivate'
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