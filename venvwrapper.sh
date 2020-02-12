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

# First: define minimal number of env vars needed to work.
# By default, everything will be located under the ~/.venv directory like so:
# ~/.venv:
#     |
#     +--- hooks
#     |
#     +--- venvs
#     |
#     +--- projects

function _check_venv_dir () {
    local varname="$1"
    local default="$2"

    # is the whatever variable empty?
    if [ -z "$varval" ]
    then
        #printf -v $varname "$default"
        eval "export $varname=$default"
    fi
    if [ ! -d ${!varname} ]
    then
        mkdir -p ${!varname}
    fi
}

# so, we need to define those directories and create them
# or inherit them from the .bashrc whence they came
_check_venv_dir "VENV_HOME_ROOT"    "$HOME/.venv"
_check_venv_dir "VENV_PROJECT_HOME" "$VENV_HOME_ROOT/projects"
_check_venv_dir "VENV_VENV_HOME"    "$VENV_HOME_ROOT/venvs"
_check_venv_dir "VENV_HOOK_HOME"    "$VENV_HOME_ROOT/hooks"

# // mkenv <venv name>
function mkvenv {
    local venv_name="$1"
    local project_fullpath="$VENV_PROJECT_HOME/$venv_name"
    local venv_fullpath="$VENV_VENV_HOME/$venv_name"

    if [ -z $venv_name ]
    then
        echo "ERROR: Please specify a name for the virtual environment you want to create!" >&2
        return 1
    fi

    if [ -d $VENV_PROJECT_HOME/$venv_name ]
    then
        echo "ERROR: Project named '$venv_name' already exists!" >&2
        return 1
    fi

    echo "Creating virtual environment for project: $env_name ..."
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

    # first, deactivate the venv currently active, if any
    # is there a deactivate function?
    if [ -n $VIRTUAL_ENV ]
    then
        typeset -f deactivate | grep 'typeset postdeactivate_hook' >/dev/null 2>&1
        # if it's our modded 'deactive' just use it
        if [ $? -eq 0 ]
        then
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
    pushd . >/dev/null
    _venv_set_cd

    # save original 'deactivate' as venv_deactivate
    local venv_deactivate="$(typeset -f deactivate | sed 's/deactivate/venv_deactivate/g')"
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

        if [ ! "$1" = "nondestructive" ]
        then
            # Remove these two functions always
            _venv_nuke_funcs "virtualenv_deactivate deactivate cd"
            _venv_nuke_vars "$VARS_USED"
            
            # pop dir stack if something is in there
            if [[ ${#DIRSTACK[@]} -gt 1 ]]
            then
                popd >/dev/null
            else
                cd
            fi
        fi
    }'
    cd
}

function _venv_nuke_funcs {
    local targets="$1"

    for t in $targets
    do
        typeset -f $t >/dev/null 2>&1
        if [ $? -eq 0 ]
        then
            unset -f $t >/dev/null 2>&1
        fi
    done
}

function _venv_nuke_vars {
    local targets="$1"

    for t in $targets
    do
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

    if [ ! -f $venv_hook ]
    then
        return 1
    fi

    if [ -n $venv_name ]
    then
        source $venv_hook $venv_name
    else
        source $venv_hook
    fi
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

function venvhelp {
    NAME="venvwrapper.sh"
    cat << EOF

-----------------------------------------------------------
$NAME = virtualenv wrapper for Python 3
-----------------------------------------------------------
Quick Usage:
    mkvenv [new_venv]       # creates a new venv and enter it
    useven [existing_venv]  # enter into already created venv
    deactivate              # deactivate and exit venv
    rmvenv [existing_venv]  # remove existing venv
    lsvenvs                 # list all available venvs

-----------------------------------------------------------

Your virtual env has two logical parts:
    1. virtual env          - Virtual Python files/libs/site-pkgs
    2. project              - your source code (for versioning)

You can define/override the following locations in your .bash_profile
    - VENV_HOME_ROOT        default (~/venv)
        + VENV_VENV_HOME    (~/.venv/venvs)
        + VENV_PROJECT_HOME (~/venv/projects)
        + VENV_HOOK_HOME    (~/venv/hooks)

-----------------------------------------------------------

EOF
if [ -n "$VIRTUAL_ENV" ];
then
cat << EOF
You're inside your venv ($VIRTUAL_ENV), so you
use the following additional commands...:
* cdvenv      your venv is here:      ($VENV_MY_VENV)
* cdsitepkgs  your site-pkgs is here: ($VENV_MY_SITEPKGS)
* cdproject   your project is here:   ($VENV_MY_PROJECT)
EOF
fi
}
