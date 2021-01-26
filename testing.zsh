#!/usr/bin/zsh

# _check_venv_dir ENV DEFAULT_VALUE
# this function checks to see if the env variable is empty or not
# if empty, assign the given default value. if not, do nothing
# finally, does the dir assigned to env var exist? if not, create it

# we're just checking for the following env vars
# "VENV_HOME_ROOT"    "$HOME/.venv"
# "VENV_PROJECT_HOME" "$VENV_HOME_ROOT/projects"
# "VENV_VENV_HOME"    "$VENV_HOME_ROOT/venvs"
# "VENV_HOOK_HOME"    "$VENV_HOME_ROOT/hooks



function _check_venv_dir () {
# what's tricky here is that we need something like ${$env_var}
# in bash, you'd use ${!env_var}
# in zsh, you have to use ${(P)env_var}
    local env_var="$1"
    local var_val="$2"

    # is the ENV variable empty?
    if [ -z "${(P)env_var}" ]
    then
        echo "export $env_var=$var_val"
    fi
    if [ ! -d "${(P)env_var}" ]
    then
        echo "mkdir -p ${(P)varname}"
    fi
}

function _check_venv_dir () {

    # what's tricky here is that we need something like ${$env_var}
    # in bash, you'd use ${!env_var}
    # in zsh, you have to use ${(P)env_var}

    local env_var="$1"
    local default_val="$2"

case whatshell in
    bash) varvar="${!env_var}"
    ;;

    zsh|-zsh) varvar="${(P)env_var}"
    ;;
esac

    local varvar="${!varname}"
    local env_var_val=${(P)env_var}

    # is the ENV variable defined?
    # ex: VENV_HOME="~/.venv" ?

    # we check to see if it's NOT defined
    # because if it IS, it means it was defined
    # from .bashrc/.zshrc or some shell startup
    # so then we do NOTHING
    if [ -z "$env_var_val" ]
    then
        echo "export $env_var=$env_var_val"
    fi

    # does the directory exist?
    if [ ! -d "$default_val" ]
    then
        echo "mkdir -p $default_val"
    fi
}

Coolduck15959@gmail.com
15959@gmail.fart

VARS_USED="\
VENV_MY_VENV_NAME \
VENV_MY_PROJECT \
VENV_MY_VENV \
VENV_MY_SITEPKGS"