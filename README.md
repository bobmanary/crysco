# crysco

Crysco is a toy Linux container implementation based on [barco](https://github.com/lucavallin/barco), rewritten in the Crystal language. It utilizes cgroups, namespaces, seccomp and capabilities to provide isolated environments. As a non-C program, it also required writing minimal bindings for libseccomp, libcap, and kernel system calls (not the libc wrappers).

It's basically fancy `chroot` and is not intended for real-world use.

## Setup/installation

Requires the libcap and libseccomp libraries and the [Crystal compiler](https://crystal-lang.org/install/).

On Debian derivatives:
```bash
sudo apt install -y libcap-dev libseccomp-dev
crystal build --release src/crysco.cr
```

## Usage

In this example, we create an environment with [BusyBox](https://en.wikipedia.org/wiki/BusyBox) utilities (note that the BusyBox shell does not display prompts properly as a result of blocking the [TIOCSTI ioctl](https://isopenbsdsecu.re/mitigations/tiocsti/) with seccomp, but should still be able to execute commands interactively):

```bash
mkdir -p ~/crysco-busybox-container/bin
mkdir -p ~/crysco-busybox-container/proc
cd ~/crysco-busybox-container/bin
wget https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
chmod +x busybox

# link typical userspace utilities to the busybox binary
while read -r cmd; do
  ln -s /bin/busybox $cmd
done < <(./busybox --list)

# cd back to your crysco repository, then:
sudo ./crysco --mount ~/crysco-busybox-container --cmd /bin/find --arg /
```

## Potential improvements

 * Update libcap and libseccomp wrappers to have similar API styles
 * Investigate interaction of pty, TIOCSTI blocking, and BusyBox shells
 * Add ability to run complete shell commands instead of having a single --arg flag
 * Add options for managing environment variables
