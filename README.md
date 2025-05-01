


**limon**

limon is shell script to color bash prompt

**Features**

![limon](https://raw.github.com/FaridRasidov/limon/master/example.png)

**Root User**
- <i>if path is  '/root*' or '/home*' colors normal and when it's in another '/*' dir red</i>

**Regular User**
- <i>if user has permission on dir colors normal and if not colors gray</i>

**Common**
- <i>checks last exit code and displays red if any errors happend</i>
- <i>shows (venv) if some virtual env is activated</i>
* <i>shows git branch name</i>
* <i>if there's Uncommitted Changes Shows "(@)"</i>
* <i>if there's commits not uploaded to remote shows "↑" and number of commits</i>
* <i>if there's commits not downloaded from remote shows "↓" and number of commits</i>
 - <i>limon has persistance mode, which means it saves your last theme settings</i>
 - <i>comes with auto completer</i> 
- <i>use bash builtin when possible to reduce delay "delay sucks!"</i>
- <i>now you can select theme from available themes</i>
- <i>no need for patched fonts</i>

**Setup Steps :**

**Download the File**
```shell
git clone https://github.com/faridrasidov/limon

sudo mv limon/ /usr/share/

sudo echo 'alias limon="source /usr/share/limon/limon.sh"' >> /etc/bash.bashrc
sudo echo 'source /usr/share/limon/hint-limon.sh' >> /etc/bash.bashrc
```
**Enable For Current User**
```shell
echo 'limon on' >> ~/.bashrc
source ~/.bashrc
```

**Enable For Global**
```shell
sudo echo 'limon on' >> /etc/bash.bashrc
sudo source /etc/bash.bashrc
```

**Change Theme**
```shell
limon on -s default
```
or
```shell
limon on -s git_bash
```

**Help**

```shell
limon is the bash color Prompt

Usage:
	on [-s] <theme_name>: turn on the limon
	off [-s]: turn off the limon and restore system PS1
	help : help to use command
	
	adding '-s' option to on/off indicated the silent mode
```


**Why limon**?

This script written in bash, which faster than Python. Yes, Python scripts are much easier to write and maintain than
Bash scripts, but invoking Python interpreter introduces noticeable delay to output. 
I hate delays, so I wrote the part which I need, with pure Bash script.

The other reason is that I don't like the idea of patching fonts. The
font patching mechanism does not work with the bitmap font 
(Apple Monaco without antialiasing) I use on non-retina screens.
I'd rather stick with existing unicode symbols.

if you have any ideas send them and we going to make better program.  

**Peace**
