#!/bin/bash

env_var="HOME"
#shell=$(ps -o args= -p "$$" | awk '{print $1}' | egrep -m 1 -o '\w{0,5}sh')
shell=$(ps -o args= -p "$$" | awk '{print $1}' | egrep -m 1 -o '\w{0,5}sh')
case $shell in
    bash) varvar="${!env_var}"
    ;;

    zsh|-zsh) varvar="${(P)env_var}"
    ;;
esac

echo $env_var

echo $shell
echo $varvar