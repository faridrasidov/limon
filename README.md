**limon**

limon is shell script to color bash prompt

**Features**

![limon](https://raw.github.com/FaridRasidov/limon/master/example.png)


- <i>If Path Is In '/root' Or '/home' Color Aqua and When it's in another '/*' Folder, Red.</i>
- <i>Checks Last Exit Code And Displays Red if ERR or Aqua OK.</i>
- <i>Shows (venv) If venv was Activated.</i>
* <i>Shows Git Branch Name.</i>
* <i>When There Is Uncommitted Changes Shows "(@)".</i>
* <i>If There Is Commits Not Uploaded To Remote Shows "↑" And Number Of Commits.</i>
* <i>If There Is Commits Not Downloaded From Remote Shows "↓" And Number Of Commits.</i>
- <i>Use Bash builtin when possible to reduce delay. Delay sucks!</i>
- <i>No Need For Patched Fonts.</i>

**Setup Steps :**

**Download the File**
```
curl https://raw.githubusercontent.com/FaridRasidov/limon/master/limon.sh > ~/limon.sh
```
**Enable For Current User**
```
echo 'source ~/limon.sh' >> ~/.bashrc
```

**Enable For Global**
```
sudo mv ~/limon.sh /root/
```
```
echo 'source /root/limon.sh' >> /etc/bash.bashrc
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
