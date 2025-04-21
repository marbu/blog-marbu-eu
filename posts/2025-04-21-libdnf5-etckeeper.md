---
title: LIBDNF 5 plugins and Etckeeper
tags: Fedora, etckeeper
toc: true
...

When [DNF package manager 5 replaced DNF 4](https://fedoraproject.org/wiki/Changes/SwitchToDnf5)
in Fedora 41, I noticed that integration between
[Etckeeper](https://etckeeper.branchable.com/) and the package
manager stopped working. I searched bugzilla and found that the problem has
been already reported as
Fedora [BZ 2326283](https://bugzilla.redhat.com/show_bug.cgi?id=2326283) and
that there was nobody working on it so far.
Since [Etckeeper is important part of my setup](/posts/2024-12-25-my-fedora-setup/#etckeeper),
I postponed upgrade to Fedora 41 on my main machine, and
started looking into how DNF 5 plugin API differs from the previous version,
and how could one get the Etckeeper integration working again.

<!--more-->

## What does the Etckeeper plugin actually do?

The upstream [python source code of the plugin](http://source.etckeeper.branchable.com/?p=source.git;a=blob;f=etckeeper-dnf/etckeeper.py;h=e8a1a5124b60ac0cf25e2a9c6b3d8d2e840b4a98;hb=HEAD)
which works with version <= 4 of DNF shows that not much is needed
([Fedora patches that a bit](https://src.fedoraproject.org/rpms/etckeeper/blob/rawhide/f/etckeeper-1.18.18-fix-output-for-ansible.patch)
to improve error checking and reporting though).
It runs `etckeeper pre-install` command before the
transaction, and if this fails it raises `dnf.exceptions.Error` exception so
that DNF won't continue with it. This is useful when you use
`AVOID_COMMIT_BEFORE_INSTALL=1` in your etckeeper configuration to make sure
DNF refuses to install (or uninstall) anything until you manually commit any
uncommitted changes in `/etc` directory.
And in a similar fashion when if the transaction finishes, it runs `etckeeper
post-install` command. That's all.

## What has changed in DNF 5?

Quick review of [DNF 5 documetation about writing
plugins](https://dnf5.readthedocs.io/en/latest/tutorial/plugins/index.html)
reveals that now the plugins needs to be implemented in C++ only, since the
whole project is implemented in C++ and it's no longer acceptable for DNF
to depend on Python or any other runtime for it's functionality.
And it makes sense: this assures that the minimal system installations are
small and easier to maintain (think about minimal buildroots or container
images). That said, it also means that the Etckeeper plugin will need to
implemented again from scratch.

## How could be the Etckeeper LIBDNF 5 plugin implemented?

To create a similar plugin for DNF 5, one need to use
[LIBDNF5 Plugin API](https://dnf5.readthedocs.io/en/latest/tutorial/plugins/libdnf5-plugins.html),
which allows to implement callbacks at
[particular breakpoints](https://github.com/rpm-software-management/dnf5/blob/main/libdnf5/plugin/iplugin.cpp)
in [DNF5 workflow](https://dnf5.readthedocs.io/en/latest/dnf5_workflow.html).

When I wanted to check what plugins already exist to better understand how
it all works, I noticed that
[list of LIBDNF5 Plugins](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/index.html#libdnf5-plugins)
is not exactly large. Fortunately one of them, so called
[Actions Plugin](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html),
looked like something I can try to use to implement the functionality I need
without writing my own plugin.

## Using Actions Plugin for Etckeeper integration

The [Actions Plugin](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html)
reads so called
["action" files](https://dnf5.readthedocs.io/en/latest/libdnf5_plugins/actions.8.html#actions-file-format)
in `/etc/dnf/libdnf5-plugins/actions.d/`
directory, and executes hooks defined in them. Since I need to execute
etckeeper pre or post install commands at given breakpoints, this seems ideal.

My first attempt looked like this:

```
# cat /etc/dnf/libdnf5-plugins/actions.d/etckeeper.actions
pre_transaction::::etckeeper pre-install
post_transaction::::etckeeper post-install
```

And for a positive use case it worked already good enough. But when I tried to
figure out how to pass a failure of `etckeeper pre-install` command to stop
DNF5 transaction in case of unclean `/etc` directory, I realized there is no
way to do so. For a while I was entertaining an idea of implementing a new
LIBDNF5 plugin, but there I also noticed that I'm not sure how to pass the
error properly.

Eventually I opened
[new feature request for DNF5](https://github.com/rpm-software-management/dnf5/issues/2023)
asking for an option (in actions file format) to make DNF5 to raise an error
when command returns non zero return code. This was shortly implemented, so
that since
[DNF5 5.2.11.0](https://github.com/rpm-software-management/dnf5/releases/tag/5.2.11.0),
it's possible to use new `raise_error=1` option to enable processing of return
code of a command in an actions file.

When I played with this new feature, I settled down on the following actions
file:

```
$ cat /etc/dnf/libdnf5-plugins/actions.d/etckeeper.actions
# to be placed in /etc/dnf/libdnf5-plugins/actions.d
# requires dnf5 5.2.11.0 or later
pre_base_setup:::raise_error=1:etckeeper pre-install
post_transaction::::etckeeper post-install
```

It uses `pre_base_setup` for the first hook so that the DNF complains
immediately when `/etc` directory is not clean. But I don't use `raise_error=1`
option for the `post_transaction` hook, since it's not necessary and when used
the Actions Plugin complains that output coming from `etckeeper post-install`
doesn't follow the expected format (obviously).

## Example of usage

I'm using the `etckeeper.actions` file as listed above for few days and so far
it seems to work well. I haven't run into any further problem.

When I have some uncommitted changes in `/etc` directory DNF5 will immediately
report and error as expected:

```
# time dnf install caddy

** etckeeper detected uncommitted changes in /etc prior to dnf run
** Aborting dnf run. Manually commit and restart.

File "/etc/dnf/libdnf5-plugins/actions.d/etckeeper.actions" on line 3: Exit code: 1

real    0m2.347s
user    0m2.205s
sys     0m0.167s
```

Then when I revert or commit the changes to make `/etc` clean again and retry,
I can see that after the package was installed, appropriate commit in `/etc`
git repository was created:

```
# git log -1 @
commit 7282591c86c9fe5dd6e7ad28c9c86feb43297da0
Author: root <root@localhost>
Date:   Sat Apr 19 15:36:02 2025 +0200

    committing changes in /etc made by "dnf install caddy"
    
    Package changes:
    +0:caddy-2.9.1-3.fc42.x86_64
    +0:fedora-logos-httpd-42.0.1-1.fc42.noarch
    +1:julietaula-montserrat-fonts-7.222-10.fc42.noarch
```

## Next steps

I [submitted the config file to the upstream](https://etckeeper.branchable.com/forum/RFE:_please_add_support_for_DNF_5/#comment-0c7b25672afd75d493fed3ae696950b8),
so hopefully it will reach Fedora in next Etckeeper release, and will be
provided in `etckeeper-dnf5` subpackage later.
In the meantime if you use Fedora 41 or 42 and want to use Etckeeper there, you
can already use the action file I posted above until that happens, just make
sure you have `libdnf5-plugin-actions` package installed.
And if you run into some problem, let me know in
[the upstream discussion](https://etckeeper.branchable.com/forum/RFE:_please_add_support_for_DNF_5/).
