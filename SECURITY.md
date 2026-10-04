# Security Policy

## Supported versions

Security fixes go into the latest release on the `stable` channel (the
`master` branch) and into `beta` and `dev`. Older releases are not patched;
please upgrade with `limon upgrade`.

| Version              | Supported |
|----------------------|-----------|
| Latest release       | ✅        |
| `beta`, `dev` branch | ✅        |
| Older releases       | ❌        |

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report it privately through GitHub instead:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**
   ([direct link](https://github.com/faridrasidov/limon/security/advisories/new)).
3. Describe the problem, how to reproduce it, and the impact you expect.
   Include your `limon version`, your Bash version and your OS.

You should get a first reply within 7 days. Once a fix is ready, it is
released and the advisory is published, crediting you unless you prefer to
stay anonymous.

## What counts as a security issue

Limon runs inside every interactive shell, so examples include:

- Prompt rendering that executes text from an untrusted source, for example a
  crafted git branch name, directory name, kubeconfig or environment value.
- The installer (`get-limon.sh`, `install.sh`), `limon upgrade` or
  `limon uninstall` writing, deleting or running files outside what they
  should, or doing so as the wrong user (for example during `--system`
  installs).
- Unsafe handling of temporary files or the config and cache directories.

Bugs in the vendored ble.sh (`vendor/blesh`) should also be reported to
[ble.sh upstream](https://github.com/akinomyoga/ble.sh); we will update the
bundled copy once it is fixed.
