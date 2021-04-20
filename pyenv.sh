#!/usr/bin/env python3

# define the system's python3 and global site pkgs
export PYENV_SYS_PYTHON="$(which python3)"
export PYENV_SYS_SITEPKGS=$( $PYENV_SYS_PYTHON -c "import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())" )
# ---------------------------------
# unset PYENV_ROOT
# unset PYENV_PROJECTS
# unset PYENV_VENVS
# unset PYENV_HOOKS
# unset PYENV_SYS_PYTHON
# unset PYENV_SYS_SITEPKGS
# ---------------------------------

# 1 - Check the appropriate environment variables are set.
#     The folllowing must be set to know how to deal with 
#     virtual environments. They specify the directories of
#     where all things go.
PYENV_VARS=( PYENV_ROOT PYENV_PROJECTS PYENV_VENVS PYENV_HOOKS )
PYENV_VARS_TO_ERASE=( PYENV_MY_SITEPKGS PYENV_MY_PROJECT PYENV_MY_VENV )

#     Check and verify the variables and that the directories exist
function checkAndSetDirsFromEnvs() {
    # @parm1: name of the env var
    # @parm2: value(directory) to set if not already set
    # logic: set the varname to desired if varname is not defined
    local varname="$1"
    local desired="$2"
    local whatitsalreadysetto=${(P)varname}
    local directory="$whatitsalreadysetto"

    # if $varname is undefined set it to $desired
    # decide whether to use desired or what it's already set to
    if [ -z "$whatitsalreadysetto" ]; then
        directory="$desired"
        eval "export $varname=$directory"
    fi

    if [ ! -e "$directory" ]; then
        echo "creating $directory"
        mkdir -p $directory
    fi
}

checkAndSetDirsFromEnvs PYENV_ROOT       ${HOME}/.venv
checkAndSetDirsFromEnvs PYENV_PROJECTS   ${PYENV_ROOT}/projects
checkAndSetDirsFromEnvs PYENV_VENVS      $PYENV_ROOT/venvs
checkAndSetDirsFromEnvs PYENV_HOOKS      $PYENV_ROOT/hooks
# Everything's checked and verified. We don't need the function
# taking up space. So just nuke it.
unset -f checkAndSetDirsFromEnvs

# -----------------------------------------------

# 2 - Make a new Python virtual environment
function _pyenv_make {
    # @parm2: name of the desired virtual environment
    local venv_name="$1"
    local project_fullpath="$PYENV_PROJECTS/$venv_name"
    local venv_fullpath="$PYENV_VENVS/$venv_name"

    # check whether virtual environment name was given. return if not.
    if [ -z "$venv_name" ]
    then
        echo "ERROR: Please specify a name for the virtual environment you want to create!" >&2
        return 1
    fi
    # check if the virtual environment already exists. return if it does.
    if [ -d "$PYENV_PROJECTS/$venv_name" ]
    then
        echo "ERROR: Project named '$venv_name' already exists!" >&2
        return 1
    fi

    echo "Creating virtual environment for project: $venv_name ..."

    # With Python 3.x it's simple as issuing ...
    $PYENV_SYS_PYTHON -m venv $venv_fullpath && mkdir $project_fullpath
    if [ $? -ne 0 ]
    then
        # There's really no reason for it err out.
        echo "ERROR: Unable to create virtual environment" >&2
        return 1
    fi
    # run the post-make hook and start using!
    _pyenv_run_hook "post_make" "$venv_name"
    _pyenv_use $venv_name
}

function _pyenv_use {
    local venv_name="$1"
    local project_fullpath="$PYENV_PROJECTS/$venv_name"
    local venv_fullpath="$PYENV_VENVS/$venv_name"

    # Python 3's virtual env implementation will define an
    # environment variable 'VIRTUAL_ENV' as the virtualenv's
    # name, if one is currently active. We check it to see
    # if we're in an virtualenv or no
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
        echo "ERROR: Environment '$venv_fullpath' cannot be activated." >&2
        return 1
    fi

    # activate the venv and set env var VENV_VENV_NAME
    # which can be used for scripting or such
    _pyenv_run_hook "pre_activate" "$venv_name"
    source "$activate"

    export PYENV_MY_SITEPKGS="$(python3 -c 'import distutils.sysconfig; print(distutils.sysconfig.get_python_lib())')"
    export PYENV_MY_PROJECT=$project_fullpath
    export PYENV_MY_VENV=$venv_fullpath

    # save the current directory
    pushd . >/dev/null
    _pyenv_set_cd

    # get a copy of 'deactivate' functions and call it pyenv_deactivate
    local pyenv_deactivate="$(typeset -f deactivate | sed 's/^deactivate/pyenv_deactivate/g')"
    eval "$pyenv_deactivate"

    unset -f deactivate >/dev/null 2>&1
    # Replace the deactivate() function with a wrapper.
    eval 'deactivate () {
        typeset postdeactivate_hook
        typeset old_env

        # Call a hook before deactivating
        _pyenv_run_hook "pre_deactivate"

        postdeactivate_hook="$PYENV_HOOKS/postdeactivate"
        old_env=$(basename "$VIRTUAL_ENV")

        echo "* deactivating $old_env"
        # DEACTIVATE!!
        pyenv_deactivate $1

        # call post-deactivate hook
        _pyenv_run_hook "post_deactivate" "$old_env"

        _pyenv_set_cd

        if [ ! "$1" = "nondestructive" ]
        then
            # get rid of all virtualenv functions and env-vars
            _pyenv_nuke_funcs virtualenv_deactivate deactivate cd
            _pyenv_nuke_vars $PYENV_VARS_TO_ERASE
            
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
    _pyenv_run_hook "post_activate" "$venv_name"
    return 0
}

function _pyenv_remove {
    local venv_name="$1"
    local project_fullpath="$PYENV_PROJECTS/$venv_name"
    local venv_fullpath="$PYENV_VENVS/$venv_name"

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

function _pyenv_ls {
    if [ ! -d $PYENV_VENVS ] && [ ! -d $PYENV_PROJECTS ] || [ ! "$(ls -A $PYENV_PROJECTS" ]
    then
        echo "ERROR: You do not have any virtual environments!" >&2
        return 1
    fi
    
    echo "Here is a list of your virtual environments:\n"
    for venv in "$PYENV_VENVS"/*
    do
        venv_name=$(basename $venv)
        if [ -d $PYENV_VENVS/$venv_name ] && [ -d $PYENV_PROJECTS/$venv_name ]
        then
            echo "  * $venv_name"
        fi
    done
    echo
}

function _pyenv_set_cd {
    # first clear any cd function, if there is one already defined
    typeset -f cd >/dev/null 2>&1
    if [ $? -eq 0 ]
    then
        unset -f cd >/dev/null 2>&1
    fi
    # auto cd'ing into the project is default 
    # if you set VENV_CD_TO_PROJECT to 'false' in .bashrc
    # cd will function as normal
    if [ -n "$VIRTUAL_ENV" ] && [ "$PYENV_CD_TO_PROJECT" != "false" ]
    then
        function cd {
            if (( $# == 0 ))
            then
                builtin cd $PYENV_MY_PROJECT
            else
                builtin cd "$@"
            fi
        }
    fi
}

function _pyenv_nuke_funcs {
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

function _pyenv_nuke_vars {
    local targets=("$@")

    for t in ${targets[@]}
    do
        #echo "nuking var: $t"
        unset $t >/dev/null 2>&1
    done
}

function _pyenv_run_hook {
    local hook_script="$1"
    local venv_name="$2"
    local venv_hook="$PYENV_HOOKS/$1"

    #echo "venv_hook = $venv_hook"
    if [ ! -f "$venv_hook" ]
    then
        return 1
    fi
    #echo "venv_name = $venv_name"
    if [ -n "$venv_name" ]
    then
        source $venv_hook $venv_name
    else
        source $venv_hook
    fi
}









function _pyenv_help {
    cat << EOF
-----------------------------------------------------------
pyenv.zsh: Python 3 virtual environment helper script
-----------------------------------------------------------

Usage: pyenv [make|use|ls|remove] [param]

    where action is:

    make [new_venv]         # creates a new venv and enter it
    use [existing_venv]     # activate an existing venv
    rmvenv [existing_venv]  # remove existing venv
    lsvenvs                 # list all available venvs
    deactivate              # deactivate and exit venv

EOF
if [ -n "$VIRTUAL_ENV" ];
then
cat << EOF
Currently, there's a virtualenv activated. So you the
following additional commands:

    pyenv cd [venv|sitepkgs|project]
        venv      your venv is here:      ($VENV_MY_VENV)
        sitepkgs  your site-pkgs is here: ($VENV_MY_SITEPKGS)
        project   your project is here:   ($VENV_MY_PROJECT)

    just 'pyenv cd' defaults to the project directory
EOF
fi
cat << EOF
-----------------------------------------------------------
pyenv directory structure:
-----------------------------------------------------------

Your virtual env has two logical parts:
    1. virtual env          - Virtual Python files/libs/site-pkgs
    2. project              - your source code (for versioning)

You can define/override the following locations in your .bash_profile
    - VENV_HOME_ROOT        default (~/.venv)
        + VENV_VENV_HOME    (~/.venv/venvs)
        + VENV_PROJECT_HOME (~/.venv/projects)
        + VENV_HOOK_HOME    (~/.venv/hooks)

-----------------------------------------------------------
EOF
}

# this is the script's main dispatcher
function pyenv() {
    local action="$1"
    local parm="$2"

    case $action in
        make|create)   _pyenv_make $parm 
                ;;
        use|workon)    _pyenv_use $parm 
                ;;
        ls|list)       _pyenv_ls
                ;;
        rm|remove)     _pyenv_remove $parm
                ;;
        *)      _pyenv_help
                ;;
    esac
}
