<div align="center">

# Loaf-Shell

<br>

**Hyprland shell — QuickShell morphing UI, themed and simple**

![HYPRLAND](https://img.shields.io/badge/Hyprland-white?style=flat-square&logo=wayland&logoColor=white&labelColor=%23492730&color=%236b3a4a) ![QUICKSHELL](https://img.shields.io/badge/QuickShell-white?style=flat-square&logo=qt&logoColor=white&labelColor=%23492730&color=%236b3a4a) ![LICENSE](https://img.shields.io/github/license/SirQuacksALot/loaf-shell?style=flat-square&logo=github&logoColor=white&labelColor=%23492730&color=%236b3a4a)


<pre>
<a href=#preview>ᴘʀᴇᴠɪᴇᴡ</a>   •  <a href=#installation>ɪɴsᴛᴀʟʟᴀᴛɪᴏɴ</a>  •  <a href=#dependencies>ᴅᴇᴘᴇɴᴅᴇɴᴄɪᴇs</a> •  <a href=#contribution>ᴄᴏɴᴛʀɪʙᴜᴛɪᴏɴ</a>
</pre>

</div>

<br>

> [!CAUTION]
> This is a project is currently not ready for daily use an will only provide a simplified feature set as it is in early development.

<a name="preview"></a>
## Preview

*Still on the way*

<a name="installation"></a>
## Installation

1. Check the <a href=#dependencies>dependencies</a> make sure everything needed is installed.
2. clone this repo with `git clone https://github.com/SirQuacksALot/loaf-shell ~.config/quickshell`

<a name="dependencies"></a>
## Dependencies

> [!TIP]
> If you use other services for specific funktionality please feel free to adapt the project to your need in your own instance.

- hyprland
- quickshell
- git
- pipewire
- UPower
- NetworkManager
- bluez
- polkit
- brightnessctl
- systemd
- awww
- curl
- libcanberra
- cliphist + w-clipboard
- lucid icons ([see icons readme](icons/README.md))

<a name="contribution"></a>
## Contribution

> [!NOTE]
> This is a private hobby project and may or may not contain ai generated or influenced content as I simply and sadly do not have the time to push this project to higher grounds and get a good grip on quickshell and qml. 

**How to commit**

1. Create an issue.

**Project management statement**

This project is made by me and for me. If any one likes the idea's concepts and implementations driving it please feel free to reuse it. 

If you want to contribut feel free to create issues and I will see if I'll find the time to implement what you request. I will however not accept any PR's as I do not have the time to check what you've contributed as stated above. If I find the time I may re-use the idea's and concept in the PR and maybe merge it but I will not guarantee it.

If you want this project to become open source managed please feel free to hard fork it and try to push it to its limits your self. It would be appreciated if you could reference this project but I do not expect you to.

<a name="hyprland-examples"></a>
## Hyprland key bind examples

**Simple**

```lua
local function ipcShellAction(name, scope)
    return hl.dsp.exec_cmd("qs ipc call " .. scope .. " toggle " .. name)
end

hl.bind(mainMod .. " + r", ipcShellAction("launcher", ""))
hl.bind(mainMod .. " + a", ipcShellAction("shell", "controlcenter"))
hl.bind(mainMod .. " + w", ipcShellAction("shell", "wallpaper"))
hl.bind(mainMod .. " + p", ipcShellAction("shell", "powermenu"))
hl.bind(mainMod .. " + c", ipcShellAction("shell", "clipboard"))
hl.bind(mainMod .. " + i", ipcShellAction("shell", "info"))
hl.bind(mainMod .. " + n", ipcShellAction("shell", "wifi"))
hl.bind(mainMod .. " + b", ipcShellAction("shell", "bluetooth"))
hl.bind(mainMod .. " + d", ipcShellAction("shell", "default"))
```

**Submap**

```lua
local function shellViewIpc(scope, name)
    return "qs ipc call " .. scope .. " toggle " .. name
end

local function shellAction(cmd)
    return hl.dsp.exec_cmd(cmd .. " && hyprctl dispatch 'hl.dsp.submap(\"reset\")'")
end

hl.bind(mainMod .. " + I", hl.dsp.submap("shell"))

hl.define_submap("shell", function()
    hl.bind(mainMod .. " + r", shellAction(shellViewIpc("launcher", "")))
    hl.bind(mainMod .. " + a", shellAction(shellViewIpc("shell", "controlcenter")))
    hl.bind(mainMod .. " + w", shellAction(shellViewIpc("shell", "wallpaper")))
    hl.bind(mainMod .. " + p", shellAction(shellViewIpc("shell", "powermenu")))
    hl.bind(mainMod .. " + c", shellAction(shellViewIpc("shell", "clipboard")))
    hl.bind(mainMod .. " + i", shellAction(shellViewIpc("shell", "info")))
    hl.bind(mainMod .. " + n", shellAction(shellViewIpc("shell", "wifi")))
    hl.bind(mainMod .. " + b", shellAction(shellViewIpc("shell", "bluetooth")))
    hl.bind(mainMod .. " + d", shellAction(shellViewIpc("shell", "default")))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

for i = 1, 10 do
    local key = i % 10
    hl.bind("ALT + " .. key, hl.dsp.focus({ workspace = i }), { submap_universal = true })
end

```

##

<br>

```
    ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀╭───────────────────────────────╮
      ⠀⠀⠀⠀⠀⠀⢀⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀    │ Works on my machine.          │
      ⠀⠀⠀⠀⠀⢀⣾⣿⡇⠀⠀⠀⠀⠀⢀⣼⡇    │ Now it can work on yours too. │
      ⠀⠀⠀⠀⠀⣸⣿⣿⡇⠀⠀⠀⠀⣴⣿⣿⠃    ╰───────────────────────────────╯
      ⠀⠀⠀⠀⢠⣿⣿⣿⣇⠀⠀⢀⣾⣿⣿⣿⠀   /
      ⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣷⣿⣿⣿⣿⡟⠀
      ⠀⠀⢰⡿⠉⠀⡜⣿⣿⣿⡿⠿⢿⣿⣿⠃⠀
      ⠒⠒⠸⣿⣄⡘⣃⣿⣿⡟⢰⠃⠀⢹⣿⡇⠀
      ⠚⠉⠀⠈⠻⣿⣿⣿⣿⣿⣮⣤⣤⣿⡟⠁⠀
      ⠀⠀⠀⠀⠀⠀⠈⠙⠛⠛⠛⠛⠛⠁⠀⠒⠤
      ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠑⠀⠀
``` 
