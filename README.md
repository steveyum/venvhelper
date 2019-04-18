# Python 3 Virtualenv helper

Python 3, since version 3.5 or so, have implemented the popular virtualenv package that's been available for Python 2.x for a while. It's now part of the standard set of modules. This new Python 3 method is the preferred way of managing Python virtual environments, as its implementation is more Pythonic, as well as being quicker, more efficient, etc. Functionality it's the same, it's just that with Python 3 you don't have to use pip to download and install it before using.

But rather using 'virtualenv' by itself, I always installed the 'virtualenvwrapper' package on top of it. This is a set of helper scripts that helps to manage your virtual environments. You simply tack it onto your .bashrc file and it adds a bunch of bash/zsh functions that makes using virtualenv easier with additional commands like:

```
workon <virtualenv name>
lssitepackages
... etc.
```

It also provides hooks that lets you add even more functionalities to  various events that occur during virtualenv's operation, such as before/after you create a virtual environment, or before/after you activate it, or deactivate it. You can define some environment variables after you activate a virtual environment, for example.

However, what I found most useful was how it helped me organize virtual environments. Typically, I prefer to keep all my virtual environments in a single folder, rather than having them scattered everywhere, which is what you'd tend to do unless you came up with a way to organize them, either manually or script assisted automatic way.

The newer iteration of virtualenvwrapper also let you separate your 'project' files from your virtualenv files, which contains things like Python binary, pip binary, activate script as well as all your custom site packages. You don't need to keep versions of these files

I want to use only Python 3 for development from now on, since 2.x will be deprecated any day now. That means saying goodbye to the old virtualenv package in favor of the new virtualenv built into Python 3. This also means saying goodbye to the virtualenvwrapper, right? Not really.

First of all, you can still use both virtualenv and virtualenvwrapper packages with Python 3. They will still work. It's just redundant. But in order to have virtualenvwrapper features, I have to go this redundant route, since it relies on the old virtualenv package.

Better solution to this was to create (or rather, re-create) a Python 3 version of virtualenvwrapper. At first, I just wanted to replicate the organizational features, but I was able to replicate the hook functionality as well. 

I call this script 'venvwrapper' and I wanted to keep everything as simple as possible. When I first sat down to review the virtualenvwrapper script in order to replicate it, I noticed how bloated it was. So many useless functions that went virtually unused as well as tons of useless environment variables. Some of this of course was due to the developer trying to juggle multiple shells: bash, zsh and even fish. Nope, mine is for bash only. 

By default, it uses a folder structure like this:

~/.venv/
      |
      +—— projects/
      |
      +—— venvs/
      |
      +—— hooks/

They are defined by the following values in the script:

```
VENV_HOME_ROOT="$HOME/.venv"										# this is the top level dir for your venvs
VENV_PROJECT_HOME="$VENV_HOME_ROOT/projects"		# where your project or source code lives
VENV_VENV_HOME="$VENV_HOME_ROOT/venvs"					# where the virtualenv binaries live
VENV_HOOK_HOME="$VENV_HOME_ROOT/hooks"					# where you'd put your hooks scripts
```

You can override any one of these or all of them before calling the script. 

```
source /usr/local/bin/venvwrapper.sh
```

The script will create all the necessary directories if run for the first time, and define some commands to help you manage your virtual environemtnts:

```
mkvenv <name of virtual environment>	# create a new venv
rmvenv <name of virtual environment>	# remove a venv
usevenv <name of virtual environment>	# activate a venv, similar to workon
lsvenvs			# list all virtual environments
cdproject		# cd into the project folder of the active venv
cdvenv			# cd into the venv folder ot the active venv
```

