# stirup

> run bash scripts over ssh

This is a make-shift client side deployment solution.

A bigger more versatile version of this is [ansible](https://www.ansible.com/),
there are others that started off small and now are too huge to be used when you
need something simple and to the point.

Stirup just tries to keep it simple ( at least in my opinion )

**Status**: In-Progress, Missing **core** features

## Documentation

- [Quick Start](#quick-start)
- [Motivation](#motivation)
- [Scope](#scope)
- [CLI](#cli-reference)
- [Configuration](#configuration-reference)
- [Caveats](#caveats)

Considering how simple this, there's hardly anything that needs explanation but
we'll still give it a bit of text to help out those who are just starting.

### Quick Start

1. Declare a config file with the name of `stirup.ini` or basically anything
   `.ini`
2. Add in basic configuration about the ssh host you wish to run the scripts on.

```ini
[connection]
;the user to connect to
user = "user"
;the ssh host address
host = "domain.com"
;a port if there's a custom one
port = "22"

[actions]
; path to the script that needs to be run, 
; this is supposed to be relative to the `.ini` file. 
; so if you have all your scripts in a `scripts` directory 
; and the .ini config is at the root of the project. 
; then the path would look like so
execute = "./scripts/exec.sh"
```

3. Run the stirup binary, you can download prebuild binaries from the releases
   page of wherever you are seeing this repository (github/codeberg).

```
$ stirup 
# or 
$ stirup ./path/to/stirup.ini
```

### Motivation

I have several ansible setups where the scripts are basically bash scripts and
are executed over on the SSH machine and they handle most of what needs to be
done, the only thing that ansible itself is handling in **those** setups is to
be able to copy the needed assets and secrets over to the ssh server.

This makes ansible a huge tool to have for stuff that could be replaced by a few
well configured bash scripts that are equally reusable.

But then context changes in these bash scripts do take a bit of time and it's
easier to do that with something that can infer the configuration from the
project directory instead (like any other decent deployment tool out there)

### Scope

`stirup` would like to be minimal and just do a few things instead of trying to
do everything.

Here's the things I wish for it to be able to do

- Run prepare and deployment scripts on the required ssh server
- Copy over assets / files to the ssh server

Thats it!

### CLI Reference

```
stirup 
  
  USAGE
  -----
    
    $ stirup 
    # ^ will look for configuration at ./stirup.ini, or 
    
    $ stirup ./path/to/config.ini

  --prepare, p    Run the prepare script from the configuration 
                  ( actions -> prepare ) before running the execute script
  --help, h       Display this help menu
```

### Configuration Reference

Here's an example configuration for you to take reference from. There's nothing
new and the entire CLI tool is just a wrapper around your native `ssh`
installation.

```ini
[connection]
user = "pi"
host = "pi.local"
port = "22"

[actions]
prepare = "./prepare.sh"
execute = "./exec.sh"
```

### Caveats

- Needs a native `ssh` installation since it's very hard to make sure that the
  compiled `libssh` version works properly on all arch's
- Binaries will work only on POSIX compatible systems since the osproc `ssh`
  execution hardly ever works properly with Windows powershell, if there are
  people willing to test this on their windows system, do let me know

License [MIT](license)
