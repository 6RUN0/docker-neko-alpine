# Neko Alpine Container

> ⚠️ Disclaimer
> This image is experimental and has not been thoroughly tested.
> It may contain bugs, incomplete configurations, or unexpected behavior.
> Use it at your own risk and do not rely on it for production deployments
> without proper testing in your environment.

This Docker image provides a lightweight Neko environment
built on Alpine Linux with a minimal Fluxbox window manager.
All features of the original [Neko project](https://github.com/m1k1o/neko)
are preserved — this image only changes the base system and service stack.

## Comparison with the Original Neko Image

| Original Neko | This Image |
| ------------- | ---------- |
| Based on **Debian** | Based on **Alpine Linux** (smaller footprint, fewer dependencies) |
| Uses **supervisor** for process management | Uses **s6-overlay v3** → lighter dependencies, more flexible initialization, predictable service handling |
| No window manager included by default | **Fluxbox** added as the default lightweight window manager |
| No terminal emulator included | **xterm** added (mainly for debugging/testing inside the container desktop) |
| Uses plain `NEKO_*` environment variables | Custom variables renamed with prefix **`X_NEKO_*`** to avoid conflicts with system and upstream variables |

## Environment Variables

| Variable | Default | Purpose | Used in |
| -------- | --------| ------- | ------- |
| `X_NEKO_USER` | `neko` | Name of the system user under which X services/environment (fluxbox, pulseaudio, neko itself) run. | Created in `user-init`; exported and used in `fluxbox`, `neko`, `pulseaudio`, `xorg-server`. |
| `X_NEKO_GROUP` | `$(X_NEKO_USER)` | Name of the primary group for the user. | Created in `user-init`; exported into the environment. |
| `X_NEKO_UID` | `10000` | UID of the created user. | `user-init` (adduser); exported into environment. |
| `X_NEKO_GID` | `$(X_NEKO_UID)` | GID for the primary group. | `user-init` (addgroup); exported into the environment. |
| `X_NEKO_USER_HOME` | `/home/$(X_NEKO_USER)` | Home directory of the user. | `user-init` (creation/ownership), working directory of services; exported in `fluxbox`, `neko`, `pulseaudio`, `xorg-server`. |
| `X_NEKO_DISPLAY` | `:99` | DISPLAY identifier for the local X server. | Exported as `DISPLAY` for all X clients and server. |
| `X_NEKO_RUNTIME_DIR` | `/tmp/runtime-$(X_NEKO_USER)` | XDG-compliant runtime directory for the user. | Exported as `XDG_RUNTIME_DIR` in `fluxbox`/`neko`/`pulseaudio`. |
| `X_NEKO_USER_SHELL` | `/bin/bash` | Login shell for the user (exported for applications). | Exported into the environment; used when creating the user. |
