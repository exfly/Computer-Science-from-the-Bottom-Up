# 进程层次结构

虽然操作系统可以同时运行多个进程，但事实上它只能直接启动一个称为init（初始简称）进程的进程。 这不是一个特别特殊的过程，除了它的PID始终为0并且它将始终运行。

所有其他过程都可以被视为此初始过程的子项。 进程有一个家族树，就像其他任何一个; 每个进程都有一个父进程，并且可以有许多兄弟，这是由同一父进程创建的进程。

当然，孩子可以创造更多的孩子，等等。

```
<!-- pstree -->
systemd─┬─VBoxService───7*[{VBoxService}]
        ├─agetty
        ├─dbus-daemon
        ├─haveged
        ├─lvmetad
        ├─sshd─┬─sshd───sshd───zsh───vim
        │      └─sshd───sshd───zsh───pstree
        ├─systemd───(sd-pam)
        ├─systemd-journal
        ├─systemd-logind
        ├─systemd-network
        ├─systemd-resolve
        ├─systemd-timesyn───{systemd-timesyn}
        └─systemd-udevd
```
