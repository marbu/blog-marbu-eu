---
title: Incremental Btrfs backup and subvolume layout
tags: Fedora, Linux, btrfs, backup
...

Last year I had to reinstall Fedora on my main machine because I
had to replace a disk there, and while doing so, I finally decided to switch to
btrfs abandoning my previous setup of ext4 volumes on [lvm
thin pool](https://man7.org/linux/man-pages/man7/lvmthin.7.html). And since
I already had btrfs on my external backup disk where I store snapshots of
`/home` volume from the machine, I had to figure out how to restore it using
[btrfs send/receive feature](https://btrfs.readthedocs.io/en/latest/Send-receive.html),
and how to update my
incremental backup script to match the new setup.
So in this post I will present simple examples to explain both my old and new
backup scheme and what I run into during the transition.

<!--more-->

I already used btrfs on few places such as some virtual
machines or offline backup devices. And many years ago when I used it on a
cheap netbook, I noticed a hard drive failure in advance thanks to checksum
errors btrfs reported. But I have never used it on my primary
machine before because I'm quite conservative with storage setup there. That
said I figured that it's time to give it a try. Fedora moved to [btrfs as a
default filesystem and volume management for
desktop installations](https://fedoraproject.org/wiki/Changes/BtrfsByDefault)
in 2020, and my confidence with this single disk use case reached
sufficient level already. Moreover I really appreciate additional data
consistency guarantees one gets with btrfs data checksumming and
[scrub](https://btrfs.readthedocs.io/en/latest/Scrub.html).

## My old backup scheme

As I noted above, I'm
backing up data from my entire `/home` partition and on the receiving end there
is an external hard drive formatted with btrfs. It's an offline incremental
backup scheme.
At the beginning of each backup, I created new btrfs snapshot from the previous
backup subvolume on the external drive, and then copied data from the home
partition to the new
subvolume snapshot via rsync. This way, rsync transfered only files which were
created or updated in the meantime while I didn't waste storage space on the
backup device thanks to btrfs COW design.
I settled on this scheme because I wanted to easily store large number of
backup snapshots and to be able to quickly restore a whole volume as well as
particular files if needed.

When I was researching this back in 2017 (yeah I was using this approach for
some time already) I was looking for a simple tool which works in
this way without being too opinionated or heavy, and eventually settled on
[rsyncbtrfs](https://github.com/oxplot/rsyncbtrfs). Even though the script is
no longer maintained since May 2019, it's small and clear enough so that
one can tweak or fix it if needed.
In my case it required additional plumbing steps, eg. I did thin lvm snapshot
of the home volume first to make sure that it's in a consistent state (this is
important because rsyncbtrfs runs rsync with
[`--inplace` option](https://explainshell.com/explain?cmd=rsync+--inplace)).
You can see all these steps in [my backup
script](https://github.com/marbu/scriptpile/blob/master/dione-btrfs-backup-saturn.sh)
which fully automates the procedure,
but such details are out of scope of this blog post.

So let's see a simple example how the backup procedure looked like, assuming we
have the target backup device available as `/dev/mapper/backup` and we want to
initialize it:

```
# mkfs.btrfs /dev/mapper/backup
# mkdir /mnt/backup/
# mount /dev/mapper/backup /mnt/backup/
# btrfs subvolume create /mnt/backup/home_snapshots
# rsyncbtrfs init /mnt/backup/home_snapshots
```

Assuming `/mnt/snap_home` contains a snapshot of the home volume,
we can run the first backup:

```
# rsyncbtrfs backup /mnt/snap_home/ /mnt/backup/home_snapshots
```

When the rsyncbtrfs backup run finishes, the `home_snapshots` subvolume will
contain a new subvolume with the backup data:

```
# btrfs subvolume list /mnt/backup/
ID 256 gen 9 top level 5 path home_snapshots
ID 257 gen 9 top level 256 path home_snapshots/2023-07-16-16:18:44
```

Then when we run the backup again later:

```
# rsyncbtrfs backup /mnt/snap_home/ /mnt/backup/home_snapshots
```

A new subvolume is created based on the latest snapshot, so that we take
advantage of COW while being able to directly access any subvolume snapshot.

```
# btrfs subvolume list /mnt/backup/
ID 256 gen 12 top level 5 path home_snapshots
ID 257 gen 11 top level 256 path home_snapshots/2023-07-16-16:18:44
ID 258 gen 12 top level 256 path home_snapshots/2023-07-16-16:19:30
```

Note that a subvolume for the latest snapshot is identified via `cur` symlink:

```
# ls -l /mnt/backup/home_snapshots/
total 4
drwxr-xr-x. 1 root root 18 Jul 16 16:16 2023-07-16-16:18:44
drwxr-xr-x. 1 root root 18 Jul 16 16:16 2023-07-16-16:19:30
lrwxrwxrwx. 1 root root 19 Jul 16 16:19 cur -> 2023-07-16-16:19:30
```

Later when we need to restore the whole volume, we just simply run rsync
from the latest `cur` (or any other) subvolume back to `/home`:

```
# rsync --archive --delete /mnt/backup/home_snapshots/cur/ /home/
```

## Moving to btrfs

Having btrfs on both source and target sides of a backup procedure makes it
possible to use 
[btrfs send/receive feature](https://btrfs.readthedocs.io/en/latest/Send-receive.html)
instead of rsync. This will result
in a filesystem closer to the original and on top of that the whole process
will be more efficient.  That said it's not a full filesystem
dump and some metadata like [file birth timestamp](../posts/2019-02-17-btime/)
or inode numbers won't be preserved.
Downside of using the same filesystem everywhere is that if you hit a
nasty insidious filesystem bug, it could in theory affect both production as
well as
backup data. Whether that is a good trade-off depends on how much you trust
additional consistency features btrfs provide.

So after I reinstalled Fedora on my machine, I started with basically
empty home subvolume and my goal was to replace it with home volume restored
from the latest backup snapshot via send/receive, so that I can continue using
it for incremental backups in the future.

First of all I mounted the backup device on the fresh system:

```
# mkdir /mnt/backup/
# mount /dev/mapper/backup /mnt/backup/
```

And created a new subvolume for local backup snapshots:

```
# btrfs subvolume create /mnt/home_snapshots
Create subvolume '/mnt/home_snapshots'
```

Then I transferred my latest home volume backup there. This is necessary because
I will need the latest backup snapshot available on both sending and receiving
side for btrfs incremental backups to work.

```
# btrfs property set -ts /mnt/backup/home_snapshots/2023-07-16-16:19:30 ro true
# btrfs send /mnt/backup/home_snapshots/2023-07-16-16:19:30 | btrfs receive /mnt/home_snapshots/
At subvol /mnt/backup/home_snapshots/2023-07-16-16:19:30
At subvol 2023-07-16-16:19:30
```

And when the send/receive finished, I was able to see the new subvolume there:

```
# btrfs subvolume list /
ID 256 gen 53 top level 5 path root
ID 257 gen 35 top level 5 path home
ID 258 gen 35 top level 256 path var/lib/portables
ID 259 gen 53 top level 256 path mnt/home_snapshots
ID 260 gen 54 top level 259 path mnt/home_snapshots/2023-07-16-16:19:30
```

Then my plan was to replace existing home subvolume with a new one I create
based on the just transferred backup snapshot. But when I tried to delete the
default home volume, it failed:


```
# btrfs subvolume delete /home
Delete subvolume (no-commit): '//home'
ERROR: Could not destroy subvolume/snapshot: Invalid argument
```

This should have warned me that something is not quite right. But instead I
just figured that I had to identify the subvolume via it's ID to get it
deleted:

```
# btrfs subvolume show /home | grep Subvolume
    Subvolume ID:       257
# btrfs subvolume delete -i 257 /home
Delete subvolume (no-commit): '/home/home'
```

While the message doesn't look reasonable (what the heck does `/home/home`
mean?) the command finished with success.
But then I noticed that `/home` directory still exists:

```
# ls -ld /home
drwxr-xr-x 1 root root 0 Jul 17 22:19 /home
```

And that it's not possible to get rid of it:

```
# rmdir /home
rmdir: failed to remove '/home': Device or resource busy
# mv /home /home-old
mv: cannot move '/home' to '/home-old': Device or resource busy
```

Even though the subvolume was really gone:

```
# btrfs subvolume list /
ID 256 gen 83 top level 5 path root
ID 258 gen 35 top level 256 path var/lib/portables
ID 259 gen 53 top level 256 path mnt/home_snapshots
ID 260 gen 56 top level 259 path mnt/home_snapshots/2023-07-16-16:19:30
```

## Btrfs layout and subvolume management

Then it hit me that I did a stupid mistake: I just deleted a subvolume which
was still mounted ignoring btrfs subvolume layout.

```
# findmnt /home
TARGET SOURCE                    FSTYPE OPTIONS
/home  /dev/vda3[/home//deleted] btrfs  rw,relatime,seclabel,compress=zstd:1,discard=async,space_cache=v2,subvolid=257
```

Theoretically I could have unmounted and removed `/home` directory and went on
as I originally intended, but that would resulted in a subvolume layout I
didn't actually intend to create.

The thing is that Fedora and most other GNU/Linux distributions with btrfs
support (such as ArchLinux or Ubuntu) uses so called
[flat subvolume layout](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Flat).
That said [the volume naming scheme may
differ](https://github.com/archlinux/archinstall/issues/781) a bit in each
distro, and thanks to [subvolumes created by
systemd](https://bbs.archlinux.org/viewtopic.php?id=260291)
the layout is actually
[mixed](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Mixed).
But for the sake of this post let's ignore such details.

This means that root of a btrfs filesystem is not mounted as  `/` (a root
volume of the operating system).
Instead `/` and other volumes like `/home` have it's own btrfs
subvolume, which is mounted
explicitly via fstab so that actual btrfs root is not mounted anywhere by
default. See our Fedora `/etc/fstab` file and note that each btrfs entry has
a subvolume directly specified via `subvol=` mount option.


```
# grep btrfs /etc/fstab 
UUID=d34e4426-020c-4636-b2bc-81100db9ce4e /                       btrfs   subvol=root,compress=zstd:1 0 0
UUID=d34e4426-020c-4636-b2bc-81100db9ce4e /home                   btrfs   subvol=home,compress=zstd:1 0 0
```

When we mount the actual btrfs root somewhere:

```
# mkdir /mnt/btrfsroot
# mount UUID=d34e4426-020c-4636-b2bc-81100db9ce4e /mnt/btrfsroot/
```

We will see that the `home` subvolume is no longer there (as expected after
it's deletion) and the only one left is `root`:

```
# ls -l /mnt/btrfsroot/
total 0
dr-xr-xr-x. 1 root root 138 Jul 17 22:15 root
```

It also means that the same subvolume is now available both via the fstab
mountpoint `/` and via it's path within the btrfs root volume `/mnt/btrfsroot/root`.

```
# ls /
afs  boot  etc   lib    media  opt   root  sbin  sys  usr
bin  dev   home  lib64  mnt    proc  run   srv   tmp  var
# ls /mnt/btrfsroot/root/
afs  boot  etc   lib    media  opt   root  sbin  sys  usr
bin  dev   home  lib64  mnt    proc  run   srv   tmp  var
```

Compared to [nested subvolume layout](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Nested)
this [flat layout](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Flat)
has few advantages for snapshot management, security and control
over mount options of each subvolume, but it also means that some operations
can't be performed without the actual btrfs root to be mounted somewhere.
And even though you need the actual root just for the subvolume management
operations, it also obviously provides full access to the data as shown above.
So even though I find reasoning behind the flat layout reasonable, I have to
admit that I'm not really a big fan of btrfs subvolume management UX
implemented via POSIX filesystem API.

Btw [the ability to delete subvolumes using subvolume
ids](https://mpdesouza.com/blog/new-btrfs-feature-delete-subvolumes-using-subvolume-ids/)
was introduced in 2020 to overcome this limitation so that management
tools like [snapper](https://en.opensuse.org/openSUSE:Snapper_Tutorial)
are able to delete a subvolume without access to the actual btrfs root.

## Restoring the home volume properly

Ok so now when we know what I did wrong, let's see what I *should have done*
instead (assuming we are starting again right after Fedora installation and
have the btrfs backup device already mounted as `/mnt/backup`). First of all,
we need to mount actual root of the btrfs filesystem somewhere (note that the
UUID is different compared to the previous example because I did this
demonstration on a fresh virtual machine and that the UUID represents the whole
btrfs filesystem, not just some of it's subvolumes):

```
# mkdir /mnt/btrfsroot
# btrfs fi show / | grep uuid
Label: 'fedora'  uuid: 55f86ec4-0eab-4cb7-ba14-0bd055bd1cc2
# mount UUID=55f86ec4-0eab-4cb7-ba14-0bd055bd1cc2 /mnt/btrfsroot/
```

Then we create a new subvolume for backup snapshots, this time under the actual
brtfs root:

```
# cd /mnt/btrfsroot/
# btrfs subvolume create home_snapshots
```

And create it's entry in `/etc/fstab`:

```
UUID=55f86ec4-0eab-4cb7-ba14-0bd055bd1cc2 /mnt/home_snapshots     btrfs   subvol=home_snapshots,compress=zstd:1,noauto 0 0
```

So that we can access it without btrfs root being mounted later:

```
# mkdir /mnt/home_snapshots
# mount /mnt/home_snapshots
```

Now we can send the backup snapshot there:

```
# btrfs send /mnt/backup/home_snapshots/cur | btrfs receive /mnt/home_snapshots/
At subvol /mnt/backup/home_snapshots/cur
At subvol 2023-07-16-16:19:30
```

Then we need to get rid of the current home volume:

```
# umount /home
# btrfs subvolume delete /mnt/btrfsroot/home
```

And now we can finally restore the home volume using subvolume snapshot:

```
# btrfs subvolume snapshot /mnt/home_snapshots/2023-07-16-16:19:30 /mnt/btrfsroot/
# cd /mnt/btrfsroot/
# mv 2023-07-16-16:19:30 home
# mount /home
```

Compared to the 1st attempt, the end result is aligned with flat subvolume
layout as I originally intended:

```
# btrfs subvolume list /
ID 256 gen 110 top level 5 path root
ID 258 gen 68 top level 256 path var/lib/portables
ID 259 gen 95 top level 5 path home_snapshots
ID 260 gen 100 top level 259 path home_snapshots/2023-07-16-16:19:30
ID 261 gen 100 top level 5 path home
```

And last but not least we can umount both `/mnt/btrfsroot` and
`/mnt/home_snapshots` volumes, since we no longer need them available. I will
only need to mount `/mnt/home_snapshots` again to be able to create new
subvolume snapshot and send it to the backup disk.

## My new backup scheme

Updating my backup script didn't seem to be a big deal at first. Just
replace the rsync run with btrfs send/receive and tweak few related details.
But it quickly turned out that this brings more new challenges than I originaly
anticipated.

Unlike with my old scheme, where I could remove snapshot of the home volume
right after the backup, here I need to keep it on the machine until the next
backup is successfully completed. This is because to use send/receive in
*incremental mode* the next time I run the backup, I need to reference the
previous snapshot via `-p` option like this:

```
# btrfs send -p $PREV_SNAP $CURR_SNAP | btrfs receive /mnt/backup/home_snapshots
```

Without specifying the previous snapshot subvolume, btrfs would not know which
data blocks are already present on the target device and so will have to send
everything all over again.

Moreover since I use multiple backup devices, I need to keep track which
snapshot is the latest on each device, so that I know which old local snapshots
are no longer needed and can be safely removed.

Another problem with multiple backup devices is that each device has unique set
of btrfs subvolumes, because they have been created and initialized
independently via rsync. This means that when I restored the home volume from
the first backup device, I can no longer run the backup to other backup device
referencing a previous snapshot via `-p` option to take advantage of the
*incremental mode* since such common snapshot obviously doesn't exist. This
unfortunately means that I had only few non-optimal options to move forward:

- Delete all snapshot subvolumes on the other backup device and start making
  backups there from scratch.
- Delete everything from the other device like in the previous case, and then 
  transfer snapshots from the 1st backup device (which I used to restore the
  home volume) to the other device via send/receive (this requires to properly
  specify previous snapshot via `-p` option when sending  each subvolume).
- Keep old snapshots on the other backup device and start making backups
  there from scratch.
  This will obviously waste lot of space (since the set of new and old backup
  volumes don't share any data blocks via COW) and depending on the size of the
  storage device, I will have to remove the old snapshots soon anyway.
  Moreover while this approach preserves the old backup snapshots, I won't be
  able to restore any of these old snapshots without causing this problem all
  over again.

This problem would not have happened if I have created subvolumes on all backup
devices from a single common btrfs filesystem via send/receive. So this is not
a problem with the btrfs itself, but rather with my transition from the old
to the new backup scheme.

And last but not least, since now I need to keep the latest snapshot volume on
the machine, I may want to update my script to allow start a backup using
the latest snaphost instead of taking a new one.

## Exploring backup tools and future work

I haven't considered switching to some established btrfs backup tool
since I had my own script, conventions, and backup devices to move along.
But now I think that if I ever need to significantly enhance my backup
scheme again, I will definitely reconsider it because as we have seen the
flexibility provided by btrfs requires more plumbing and management work.
Whether I will end up doing that will depend on cost of changing conventions to
match the existing tool, and whether the tool can handle my use case as well as
the intended enhancements.

That said if you are not constrained by existing backup devices or conventions,
I would definitely recommend start with learning about core btrfs features such
as subvolume management and send/receive and then start looking into well known
tools before coming up with a custom solution.

I briefly searched the internet, looking at a list of tools implementing
[incremental backup to external drive](https://wiki.archlinux.org/title/btrfs#Incremental_backup_to_external_drive)
and list of [available backup tools](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/Incremental_Backup.html#Available_Backup_Tools),
and my options basically boils down to:

- [snapper](https://wiki.archlinux.org/title/Snapper) in combination with
  [snapsync](https://github.com/doudou/snapsync),
  [snap-sync](https://github.com/baod-rate/snap-sync) or
  [dsnap-sync](https://github.com/rzerres/dsnap-sync)
- [btrbk](https://digint.ch/btrbk/)
- [buttersink](https://github.com/AmesCornish/buttersink)

My initial impression based on skimming the docs and blog posts (so take it
with a grain of salt) is that btrbk looks most promising. It [can be used
for my use case](https://lukas.zapletalovi.com/posts/2022/fast-backups-of-fedora-with-btrbk/)
and [it seems more flexible compared to
snapper](https://ounapuu.ee/posts/2022/07/09/btrbk-is-awesome/).
Also this [discussion on reddit](https://old.reddit.com/r/btrfs/comments/y7pm5c/incremental_backup_of_snapper_to_external_drive/) shows that I'm not the only one with a similar impression.

During this research, I also realized that btrfs flexibility and UX combined
with lack of universal conventions in some cases (eg. where would one place
snapshots of a volume, differences in subvolume layouts and naming schemes,
where to mount actual btrfs root subvolume, ...)
makes some of the existing tools not directly usable in given configuration or
hard to combine with other btrfs tools. For example
[btdu](https://github.com/CyberShadow/btdu) would not work with default Fedora
btrfs system layout out of the box because btdu requires actual btrfs root to
be mounted somewhere or
[timeshift assumes that subvolume names starts with `@`](https://github.com/teejee2008/timeshift/issues/370).
I wonder why this is the case. For example git is also quite flexible and
complex, but unlike btrfs tooling ecosystem, there are lot of existing single
purpose tools which can be combined together just fine.

## References

- [Btrfs](https://fedoraproject.org/wiki/Btrfs) on [Fedora Project
  Wiki](https://fedoraproject.org/wiki/Fedora_Project_Wiki)
- [Disk Configuration](https://docs.fedoraproject.org/en-US/workstation-docs/disk-config/#_btrfs)
  from Fedora Workstation Documentation
- [Incremental
  Backup](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/Incremental_Backup.html)
  from [archived Btrfs wiki](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/Main_Page.html)
- [Btrfs Incremental backup to external drive](https://wiki.archlinux.org/title/btrfs#Incremental_backup_to_external_drive)
  from [ArchWiki](https://wiki.archlinux.org/title/ArchWiki:About)
- [Several basic schemas to layout
  subvolumes](https://archive.kernel.org/oldwiki/btrfs.wiki.kernel.org/index.php/SysadminGuide.html#Layout)
  from archived Btrfs wiki
- [An overview for the stability status of the features BTRFS supports](https://btrfs.readthedocs.io/en/latest/Status.html) from Btrfs documentation
