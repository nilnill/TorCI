# TorCI

TorCI is a Configuration Interface for TorBox. It is implemented in the [Nim](https://nim-lang.org) programming language.

<b>WARNING: THIS IS A BETA VERSION, THEREFORE YOU MAY ENCOUNTER BUGS. IF YOU DO, OPEN AN ISSUE VIA OUR GITHUB REPOSITORY.</b>

## Installation

### Nimble

To compile the scss files, you need to install `libsass`. On Ubuntu and Debian, you can use `libsass-dev`.

```bash
$ git clone https://github.com/Nil0x0/torci
$ cd torci
$ nimble build
$ nimble scss
```

and Run:

```bash
$ sudo ./torci
```

## SystemD
You can use the SystemD service (install it on `/etc/systemd/system/torci.service`)

To run TorCI via SystemD you can use this service file:

```ini
[Unit]
Description=front-end for TorBox
After=syslog.target
After=network.target

[Service]
Type=simple

User=root

WorkingDirectory=/home/torbox/torci
ExecStart=/home/torbox/torci/torci

Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
```