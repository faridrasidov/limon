## LinuxTheme

Bash script Theme For Your Terminal.

**Features**

![LinuxTheme](https://raw.github.com/FaridRasidov/LinuxTheme/master/example.png)


- If Path Is In '/root' Or '/home' Color Aqua and When it's in another '/*' Folder, Red.
- Checks Last Exit Code And Displays Red if ERR or Aqua OK.
* Shows Git Branch Name.
* When There Is Uncommitted Changes Shows "●".
* If There Is Commits Not Uploaded To Remote Shows "↑" And Number Of Commits.
* If There Is Commits Not Downloaded From Remote Shows "↓" And Number Of Commits.
- Use Bash builtin when possible to reduce delay. Delay sucks!
- No Need For Patched Fonts.

**Setup Steps :**

**Download the File**
```
curl https://raw.githubusercontent.com/FaridRasidov/LinuxTheme/master/LinuxTheme.sh > ~/linuxtheme.sh
```
**Enable For Current User**
```
chmod +x ~/linuxtheme.sh
```
```
echo 'source ~/linuxtheme.sh' >> ~/.profile
```

**Enable For Global**
```
sudo mv ~/linuxtheme.sh /etc/profile.d/ ; sudo chmod +x /etc/profile.d/linuxtheme.sh
```
```
sudo source /etc/profile.d/linuxtheme.sh
```


**Why LinuxTheme**?

This script written in bash, which faster than Python. Yes, Python scripts are much easier to write and maintain than
Bash scripts, but invoking Python interpreter introduces noticeable delay to output. 
I hate delays, so I wrote the part which I need, with pure Bash script.

The other reason is that I don't like the idea of patching fonts. The
font patching mechanism does not work with the bitmap font 
(Apple Monaco without antialiasing) I use on non-retina screens.
I'd rather stick with existing unicode symbols.

if you have any ideas send them and we going to make better program.  

**Peace**