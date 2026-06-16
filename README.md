# remote_jupyter

Bash script to launch Jupyter Lab on a remote server via SSH, open an SSH tunnel, and open the browser — all in one command.
Mostly built by LLM (Claude code, Sonnet 4.6).

## Requirements

- Local: macOS or Linux, `ssh`, `lsof`
- Remote: `zsh`, Jupyter Lab (Jupyter Server ≥2 / Lab ≥4)
- SSH key-based authentication (no password prompt)

## Usage

```sh
./remote_jupyter.sh [options] user@host
```

Connects to Jupyter Lab on the remote server. If it is not running, starts it first, then opens an SSH tunnel and launches the browser. If it is already running, skips the start step and connects directly.

```sh
./remote_jupyter.sh user@myserver
```

Options:

| Flag | Default | Description |
|---|---|---|
| `-r PORT` | `8889` | Remote port for Jupyter Lab |
| `-l PORT` | `8889` | Local port for the SSH tunnel |
| `-d DIR` | remote home | Remote notebook directory (ignored if already running) |

Examples:

```sh
# Custom ports
./remote_jupyter.sh -r 8890 -l 8890 user@myserver

# Start in a specific directory
./remote_jupyter.sh -d /home/user/projects user@myserver
```

### stop

Stops the remote Jupyter Lab server and closes the SSH tunnel.

```sh
./remote_jupyter.sh stop user@myserver
```

Use `-r` / `-l` if you started with non-default ports.

## Notes

- Authentication is disabled (`--IdentityProvider.token=`). Access is protected by the SSH tunnel itself.
- Remote startup logs are written to `/tmp/jupyter_<PORT>.log` on the server.
- For Jupyter Server <2 (Lab <4), change `--IdentityProvider.token=` to `--ServerApp.token=` in the script.
- The remote shell is `zsh`. `~/.zshrc` is sourced on each SSH call to ensure PATH (e.g. pyenv/anyenv) is available.

## Contributors

- @ryokbys


## License

MIT
