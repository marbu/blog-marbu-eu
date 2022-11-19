---
title: Tracing open() syscalls during boot with journald
tags: systemd, eBPF, Fedora, Linux
...

For debugging purposes, I needed to figure out which processes open and change
particular set of config files early during boot process.
I could have used
[inotify](https://man7.org/linux/man-pages/man7/inotify.7.html) and setup a
watch for these files, but since I was also interested to learn what *other
files* the unknown processes open, I figured that
this is an ideal opportunity for checking out [eBPF
tracing](https://www.brendangregg.com/blog/2019-01-01/learn-ebpf-tracing.html)
ecosystem.
And it turned out that it's not just a nice example of how to (not) use
[bcc](https://github.com/iovisor/bcc) tools, but in this post we will also
learn a bit about [systemd
journal](https://wiki.archlinux.org/title/Systemd/Journal).

<!--more-->

Since my tracing needs were quite simple, I have no trouble finding
existing bcc tool for this purpose: [opensnoop traces `open()`
syscalls](https://github.com/iovisor/bcc/blob/master/tools/opensnoop_example.txt)
with enough details. On Fedora these bcc scripts are provided in
[`bcc-tools` package](https://packages.fedoraproject.org/pkgs/bcc/bcc-tools/),
which installs them into `/usr/share/bcc/tools/` directory. So strictly
speaking, these scripts are provided as documentation/examples, but nothing
prevents you from using them directly:

```
# /usr/share/bcc/tools/opensnoop -TUe
TIME(s)       UID   PID    COMM               FD ERR FLAGS    PATH
0.000000000   999   639    systemd-oomd       11   0 02000000 /proc/meminfo
0.250369000   0     710    abrt-dump-journ     4   0 02004000 /var/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
0.250542000   0     690    in:imjournal        9   0 02004000 /var/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
0.250233000   999   639    systemd-oomd       11   0 02000000 /proc/meminfo
0.250630000   0     709    abrt-dump-journ     4   0 02004000 /var/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
0.250845000   0     711    abrt-dump-journ     4   0 02004000 /var/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
0.348312000   0     1317   tmux: server       10   0 00000000 /proc/1410/cmdline
0.407280000   0     1432   ls                  3   0 02000000 /etc/ld.so.cache
0.407394000   0     1432   ls                  3   0 02000000 /lib64/libselinux.so.1
0.407637000   0     1432   ls                  3   0 02000000 /lib64/libcap.so.2
0.408237000   0     1432   ls                  3   0 02000000 /lib64/libc.so.6
0.408499000   0     1432   ls                  3   0 02000000
0.411039000   0     1432   ls                 -1   2 02000000 /usr/lib/locale/locale-archive
0.411122000   0     1432   ls                  3   0 02000000 /usr/share/locale/locale.alias
0.411263000   0     1432   ls                 -1   2 02000000 /usr/lib/locale/en_US.UTF-8/LC_IDENTIFICATION
^C
```

Btw this and other examples shown in this post were performed on a small
virtual machine running Fedora 37 with bcc-tools 0.24.0, systemd 251.5 and
Linux kernel 5.19.14.

If no existing bcc tool matched my needs, my next step would have been to
try to create a simple [bpftrace](https://github.com/iovisor/bpftrace) script.
Bpftrace is a high level language which compiles to eBPF bytecode, and unless
you need to tweak or do something specific, bpftrace is preferable over bcc.

## Systemd unit file

Since I wanted to start the tracing during boot, I created the following
simple [systemd service
unit](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
and placed it in `/etc/systemd/system/opensnoop.service` file:

``` ini
[Unit]
Description=Run opensnoop trace

[Service]
Type=simple
RemainAfterExit=yes
ExecStart=/usr/share/bcc/tools/opensnoop -TUe
TimeoutStartSec=0

[Install]
WantedBy=default.target
```

And then I instructed systemd to start the service at boot:

```
# systemctl enable opensnoop
Created symlink /etc/systemd/system/default.target.wants/opensnoop.service → /etc/systemd/system/opensnoop.service.
```

## Testing the service

So far so good. But when I started the service to check how it works before I
reboot and actually use it for the debugging, I noticed a problem:

```
# systemctl start opensnoop
# journalctl -u opensnoop --since 19:53:11 -n 10
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.174630000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.174709000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.174781000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.174849000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.174930000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.175012000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.175082000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.175152000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.175228000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
Oct 16 19:53:11 localhost.localdomain opensnoop[1732]: 0.175298000   0     558    systemd-journal    -1   2 02004002 /run/log/journal/a11f78c759ef4abd8cdee24ab335036d/system.journal
```

Most of the log entries systemd journal provided for this service were related
to the journal itself. Moreover the sheer number of log entries were bit larger
than expected:

```
# journalctl -u opensnoop --since 19:53:11 --until 19:53:12 | wc -l
10532
# journalctl -u opensnoop --since 19:53:11 --until 19:53:12 | grep systemd-journal | wc -l
9493
```

Ops. At first I thought that systemd is isolating the unit somehow, but then I
immediately realized that the BPF program is running in kernel space, so that
this hypothesis doesn't make any sense. Moreover systemd journal is not exactly
running within the unit.

When I tried to filter the journald related lines out to see what *other*
messages are there, I noticed that sometimes journal was hitting it's default
rate limit and so some log lines were dropped:

```
# journalctl -u opensnoop | grep Suppressed | head
Oct 16 19:53:40 localhost.localdomain systemd-journald[558]: Suppressed 4867 messages from opensnoop.service
Oct 16 19:54:11 localhost.localdomain systemd-journald[558]: Suppressed 4975 messages from opensnoop.service
Oct 16 19:54:41 localhost.localdomain systemd-journald[558]: Suppressed 4678 messages from opensnoop.service
Oct 16 20:23:53 localhost.localdomain systemd-journald[558]: Suppressed 6810 messages from opensnoop.service
Oct 16 20:24:23 localhost.localdomain systemd-journald[558]: Suppressed 10785 messages from opensnoop.service
Oct 16 20:24:53 localhost.localdomain systemd-journald[558]: Suppressed 6400 messages from opensnoop.service
Oct 16 20:25:23 localhost.localdomain systemd-journald[558]: Suppressed 6242 messages from opensnoop.service
Oct 16 20:25:53 localhost.localdomain systemd-journald[558]: Suppressed 4864 messages from opensnoop.service
Oct 16 20:26:23 localhost.localdomain systemd-journald[558]: Suppressed 32437 messages from opensnoop.service
Oct 16 20:26:54 localhost.localdomain systemd-journald[558]: Suppressed 19087 messages from opensnoop.service
```

Or in other cases, it was the opensnoop tool reporting lost samples:

```
# journalctl -u opensnoop | grep -i lost | head
Oct 16 20:25:56 localhost.localdomain opensnoop[1900]: Possibly lost 156 samples
Oct 16 20:25:56 localhost.localdomain opensnoop[1900]: Possibly lost 112 samples
Oct 16 20:26:25 localhost.localdomain opensnoop[1900]: Possibly lost 1096 samples
Oct 16 20:26:25 localhost.localdomain opensnoop[1900]: Possibly lost 2424 samples
Oct 16 20:26:26 localhost.localdomain opensnoop[1900]: Possibly lost 4860 samples
Oct 16 20:26:26 localhost.localdomain opensnoop[1900]: Possibly lost 1 samples
Oct 16 20:26:26 localhost.localdomain opensnoop[1900]: Possibly lost 501 samples
Oct 16 20:26:26 localhost.localdomain opensnoop[1900]: Possibly lost 323 samples
Oct 16 20:26:26 localhost.localdomain opensnoop[1900]: Possibly lost 125 samples
Oct 16 20:33:58 localhost.localdomain opensnoop[1900]: Possibly lost 14 samples
```

This means that in those cases kernelspace BPF part of opensnoop tool was
inserting events into a perf buffer faster than it's userspace part was
able to read them. If I really wanted to handle such load, I would have to
learn about [low level bcc
programming](https://github.com/iovisor/bcc/blob/master/docs/reference_guide.md).
But that was not the case here, the number of log lines were definitely higher
than expected.

And then it occurred to me that I'm observing some kind of a chain reaction
which is happening because to process a log message journald uses the same
syscall I decided to trace.
So every time opensnoop observes `open()` syscall, it reports a log line
to it's standard output, which is then captured by journald using
at least one `open()` syscall during this process. That is observed by
opensnoop and the cycle starts again.

## Bypassing journald

This is not good. Logging via journald is obviously not suitable for
this ~~use~~ edge case. Fortunately systemd provides a way to avoid journal
processing via option
[`StandardOutput=file:/some/path`](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#StandardOutput=)
redirecting stdout of a systemd unit
into a file. [The feature](https://github.com/systemd/systemd/pull/7198) is
available since systemd v236 from Dec 2017.

So I added the option into my unit file:

``` diff
@@ -5,6 +5,7 @@
 Type=simple
 RemainAfterExit=yes
 ExecStart=/usr/share/bcc/tools/opensnoop -TUe
+StandardOutput=file:/var/log/opensnoop.log
 TimeoutStartSec=0
 
 [Install]
```

And when I reloaded and restarted the service, all the log messages landed in
`/var/log/opensnoop.log` instead of systemd journal, so that no entries were
missing and no irrelevant repetitive lines were present. With this I was able
to figure out what was to blame for changes in my config files.

## Cleaning up the logs and journal

After the debugging, the service and it's `opensnoop.log` file were no longer
useful so I removed them both. But then I realized that I
don't know how to delete journald messages related to the opensnoop service. In
this particular case, cleaning journal would be even more useful than removing
the log file, since I managed to store lot of irrelevant mess there by mistake.

But it turns out that [it's not directly possible to remove journal messages
for a particular
unit](https://unix.stackexchange.com/questions/272662/how-do-i-clear-journalctl-entries-for-a-specific-unit-only/616732#616732),
because [journal on-disk binary file
format](https://systemd.io/JOURNAL_FILE_FORMAT/) is designed as append only for
performance and robustness reasons.
Journal data files are actually never changed in any other way. [Cleaning old
journal
entries](https://nts.strzibny.name/cleaning-up-systemd-journal-logs-on-fedora/)
depends on the fact that systemd journal rotates journal file
every now and then to prevent it to grow over
[`SystemMaxFileSize`](https://www.freedesktop.org/software/systemd/man/journald.conf.html#SystemMaxUse=)
(or when one triggers it manually via `journalctl --rotate`).
So when you ask journalct to remove old data (either by date or size),
it only removes appropriate number of oldest rotated so called archived journal
files without touching the active journald file.

So in theory [there is a way to get rid of particular journal
entries](https://unix.stackexchange.com/questions/272662/how-do-i-clear-journalctl-entries-for-a-specific-unit-only/616732#616732).
One can rotate journal and then based on archived journal files create new set
of these files without entries from the target unit.
Then the last step would be to carefully replace the old archived journal files
with the new ones.
The problem is that journalctl doesn't provide such feature directly, and one
would either have to write a custom program using [systemd journal c
api](https://www.freedesktop.org/software/systemd/man/sd-journal.html)
(directly
or eg. [via python bindings](https://github.com/Mortal/cournal)), or use
[journal export
output](https://www.freedesktop.org/wiki/Software/systemd/export/) and
drop the target entries from the plain text export via a script before
converting it back into a binary form via
[systemd-journal-remote](https://www.freedesktop.org/software/systemd/man/systemd-journal-remote.service.html).

Either way, this is not something you want to do on a production system without
proper testing. So chances are that you will rather just rotate the
journal, and then clean it up after some time. This is what I ended up doing,
so take my description above with a grain of salt since I haven't actually
tested it.

This also made me wonder whether I could have configured systemd journal to use
different journal file for the opensnoop service. Deleting archive files for
this separate journal would be easy. Needless to say that this wouldn't help me
deal with my particular problem with already polluted journal. Moreover it
turned out that [this is not
possible](https://github.com/systemd/systemd/issues/4751).
That said one can configure a [journal
namespace](https://wiki.archlinux.org/title/Systemd/Journal#Per_unit_size_limit_by_a_journal_namespace)
so that a separate systemd journal instance with it's own journal file will
receive logs from services using the namespace. This seems useful when one
needs to configure systemd journal differently for particular set of services,
but using it for a single service looks like an overkill.

So the next time I need to run some debugging or testing service, I will
include `StandardOutput=file:` option into it's unit file from the beginning so
that I won't have this problem in the first place.
