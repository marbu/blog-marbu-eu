---
title: Minimal xmonad config
tags: xmonad, haskell, fedora
...

Some time ago, a colleague asked me how to configure special keys for volume or
brightness control in xmonad when he noticed I'm xmonad user as well. In other
words, he was interested in a config file which is as simple as possible and
which can define actions for these special keys found on all modern laptops.

So let's see the minimal example of such configuration I come up with (on
Fedora 33 machine with `xmonad-0.15-7.fc33.x86_64` package):

```
import Graphics.X11.ExtraTypes.XF86

import XMonad
import XMonad.Config
import XMonad.Util.EZConfig

myKeys = [
   ((0, xF86XK_AudioRaiseVolume),  spawn "amixer -D pulse sset Master 10%+")
 , ((0, xF86XK_AudioLowerVolume),  spawn "amixer -D pulse sset Master 10%-")
 , ((0, xF86XK_AudioMute),         spawn "amixer -D pulse sset Master toggle")
 , ((0, xF86XK_AudioMicMute),      spawn "amixer -D pulse sset Capture toggle")
 , ((0, xF86XK_MonBrightnessUp),   spawn "brightnessctl set +10%")
 , ((0, xF86XK_MonBrightnessDown), spawn "brightnessctl set 10%-")
 ]

main = xmonad $ def `additionalKeys` myKeys
```

First of all we need to import
[Graphics.X11.ExtraTypes.XF86](https://hackage.haskell.org/package/X11-1.9.2/docs/Graphics-X11-ExtraTypes-XF86.html)
module, which defines `KeySym` constants like `xF86XK_AudioRaiseVolume` we want
to use in our definition of key shortcuts.

Then we create `myKeys` list with definitions of key shortcut actions as
understood by `additionalKeys` function from
[XMonad.Util.EZConfig](https://hackage.haskell.org/package/xmonad-contrib-0.16/docs/XMonad-Util-EZConfig.html)
module. As you can see, each key listed there starts a subprocess with given
command via [`spawn` function](https://hackage.haskell.org/package/xmonad-contrib-0.16/docs/XMonad-Config-Prime.html#v:spawn).

And finally, we add `myKeys` configuration on top of default xmonad
configuration `def` via `additionalKeys` function, and pass the result
to `xmonad`.

If you want to build your own configuration on top of this example, I suggest
to start with [xmonad page on archlinux
wiki](https://wiki.archlinux.org/index.php/Xmonad#Configuration). The
introduction there is very nice, references [upstream haskell
wiki](https://wiki.haskell.org/Xmonad/Config_archive) when necessary and I just
added [a note about `Graphics.X11.ExtraTypes.XF86` module with a simple
example](https://wiki.archlinux.org/index.php/Xmonad#Targeting_unbound_keys)
similar to what is shown in this post.
