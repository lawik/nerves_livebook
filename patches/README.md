# Patches applied to deps for the boot-speed experiments

These are applied by hand to `deps/` (they are candidates for upstream PRs):

```sh
patch -p1 -d deps/nerves_ssh < patches/nerves_ssh-1.3.2-skip-fake-passwd-checker.patch
mix deps.compile nerves_ssh
```

* `nerves_ssh-1.3.2-skip-fake-passwd-checker.patch` - `NervesSSH.Options`
  calls `:ssh_options.handle_options(:server, algorithm_opts)` only to resolve
  the host key algorithms. Without a `:pwdfun`, OTP's ssh adds a "fake
  password checker" to server options, which costs 600,000 PBKDF2-HMAC-SHA256
  iterations (`crypto:pbkdf2_hmac/5`) and is never used. Passing a dummy
  `:pwdfun` skips it. Measured on QEMU (cortex-a53 emulation, 1 vCPU):
  NervesSSH process reductions 6.5M -> 14k, time-to-IEx 10.0 s -> 9.4 s.
