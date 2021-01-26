#!/usr/bin/env zsh

# This is a rewrite of my useful venv which replicates
# the functions of virtualenvwrapper for Python 2.x
# Since Python 3.x now has virtualenv functions built-in
# you no longer need virtualenv + wrapper combo... all you
# need is a wrapper.
# With this in mind, I'd created venvwrapper script and it
# worked very well. But after Apple defaulted to zsh from bash,
# I saw that my script had many errors and shortcomings.
# To address that and the unwieldy syntax (mkvenv, lsvenvs, etc)
# I decided to rewrite the whole fucking thing

export V6_PYTHON="$(which python3)"
export V6_SITEPKGS=$($V6_PYTHON -c "import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())")

# as is the case, the toughest part of writing this script is the 
# naming convention, at least one done in a way that makes sense to me.
# So, here it is: V6_xyz is for V6 global vars,
#                   V6_MY_abc is specific for MY virtual env
# global vars used: 
#           V6_ROOT          -> root directory of ALL venvs
#           V6_PROJECTS      -> your project location
#           V6_VENVS         -> your binary + pkgs directory
#           V6_HOOKS         -> your hook scripts
export V6_VARS=( V6_ROOT V6_PROJECTS V6_VENVS V6_HOOKS )
# export V6_VARS2=(VENV_VENV VENV_PROJECT VENV_VENV VENV_SITEPKGS)
# export V6_VARS_USED=(V6_NAME V6_PROJECT V6_VENV V6_SITEPKGS)

# -----------------------------------------------------------------------------------------------------------------
# SYNTAX: _envar "ENVAR" ["desiredValue"]
#   * the function will assign ENVAR="desiredValue"
#     only if ENVAR is either not set or is empty
#   * if ENVAR is already defined "desiredValue" is ignored!
#   * just calling _envar "ENVAR" will return the value of ENVAR
function _envar () {
    local envar="$1"    # ie, "HOME"
    local whatItContains="${(P)envar}"  # "$HOME"

#echo "envar=$envar, contains=$whatItContains, "

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
        #echo $desiredValue
        return
    fi
}

# - create foundation directories for venv to work
function _endir {
    local varname="$1"
    local desiredVal="$2"

#    echo "var=$varname, desiredvalue=$desiredVal"
    local dir=$(_envar $varname $desiredVal)
    #echo "checking directory: $dir"
    if [ ! -e $dir ];
    then
        #echo "mkdir $dir"
    fi
}
_endir V6_ROOT      "$HOME/.venv"
_endir V6_PROJECTS  "$V6_ROOT/projects"
_endir V6_VENVS     "$V6_ROOT/venvs"
_endir V6_HOOKS     "$V6_ROOT/hooks"
#------------------------------------------------------------------------
# declare -A VENV_DIRS
# VENV_DIRS['VENV_ROOT']="$HOME/.venv"
# VENV_DIRS['VENV_PROJECT']="$VENV_ROOT/projects"
# VENV_DIRS['VENV_VENV']="$VENV_ROOT/venvs"
# VENV_DIRS['VENV_HOOK']="$VENV_ROOT/hooks"

# function checkDirs {
#     for e in $(seq 1 $#VENV_VARS)
#     do
#         v=$VENV_VARS[$e]
#         echo -n "v = $v"
#         echo " ($(_envar $v))"
#         d=$VENV_DIRS['$v']
#         echo "d = $d"

#         dir=$(_envar $v $d)
#         echo "Checking dir: $d ($dir)"
#         if [ ! -e $dir ];
#         then
#             echo "\tmkdir $dir"
#         fi
#     done
# }
# ------------------------------------------------

function _v6_make {
    local venv_name="$1"
    local project_fullpath="$V6_PROJECTS/$venv_name"
    local venv_fullpath="$V6_VENVS/$venv_name"

    if [ -z "$venv_name" ]
    then
        echo "ERROR: Please specify a name for the virtual environment you want to create!" >&2
        return 1
    fi

    if [ -d "$V6_PROJECTS/$venv_name" ]
    then
        echo "ERROR: Project named '$venv_name' already exists!" >&2
        return 1
    fi

    echo "Creating virtual environment for project: $venv_name ..."
    $V6_PYTHON -m venv $venv_fullpath && mkdir $project_fullpath
    if [ $? -ne 0 ]
    then
        echo "ERROR: Unable to create virtual environment" >&2
        return 1
    fi
    _venv_run_hook "post_make" "$venv_name"
    usevenv $venv_name
}

function _v6_list {
    local venv_name="$1"
    local project_fullpath="$V6_PROJECT/$venv_name"
    local venv_fullpath="$V6_VENV/$venv_name"

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
    _v6_run_hook "pre_activate" "$venv_name"
    source "$activate"

    export V6_MY_SITEPKGS="$(python3 -c 'import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())')"
    export V6_MY_PROJECT=$project_fullpath
    export V6_MY_VENV=$venv_fullpath

    # save the current directory
    #echo "pushing current dir into stack"
    pushd . >/dev/null
    _v6_set_cd

    # get a copy of 'deactivate' functions and call it v6_deactivate
    local v6_deactivate="$(typeset -f deactivate | sed 's/^deactivate/v6_deactivate/g')"
    eval "$v6_deactivate"

    unset -f deactivate >/dev/null 2>&1
    # Replace the deactivate() function with a wrapper.
    eval 'deactivate () {
        typeset postdeactivate_hook
        typeset old_env

        # Call a hook before deactivating
        _venv_run_hook "pre_deactivate"

        postdeactivate_hook="$V6_HOOK/postdeactivate"
        old_env=$(basename "$VIRTUAL_ENV")

        # DEACTIVATE!!
        v6_deactivate $1

        # call post-deactivate hook
        _venv_run_hook "post_deactivate" "$old_env"

        _v6_set_cd

        if [ ! "$1" = "nondestructive" ]
        then
            # get rid of all virtualenv functions and env-vars
            _v6_nuke_funcs virtualenv_deactivate deactivate cd
            _v6_nuke_vars $(echo "$VARS_USED")
            
            # pop the directory stack if something is there
            if [[ $(dirs -v | wc -l) -gt 1 ]]
            then
                popd >/dev/null
            else
                cd
            fi
        fi
    }'
    cd
    _v6_run_hook "post_activate" "$venv_name"
    return 0
}

function _v6_list {
    if [ ! -d $V6_MY_VENV ] && [ ! -d $V6_MY_PROJECT ]
    then
        echo "ERROR: You do not have any virtual environments!" >&2
        return 1
    fi
    for venv in "$V6_VENVS"/*
    do
        venv_name=$(basename $venv)
        if [ -d $V6_VENVS/$venv_name ] && [ -d $V6_PROJECTS/$venv_name ]
        then
            echo $venv_name
        fi
    done
}

function cdvenv {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $V6_MY_VENV
    fi
}

function cdproject {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $V6_MY_PROJECT
    fi
}

function cdsitepkgs {
    if [ -n "$VIRTUAL_ENV" ]
    then
        cd $V6_MY_SITEPKGS
    else
        cd $V6_SITEPKGS
    fi
}