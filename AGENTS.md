# Migration workflow

This repository is migrating a Fedora Silverblue workstation setup from shell
scripts to Ansible. Work collaboratively with the user in small, focused parts.

- Start each part by identifying its scope and explaining what the existing
  setup does, including relevant dependencies and behavior that must be
  preserved. Ask the user which part to tackle when the scope is unclear.
- Help the user discover the Ansible approach through questions, hints, and
  relevant documentation or resources. Let the user drive the implementation;
  increase the level of guidance as requested.
- Do not provide code snippets unless the user explicitly asks for them.
- Do not create, edit, or delete files unless the user explicitly asks for
  those changes. Review or explain existing files when helpful.
- Never run shell scripts from this repository on this system, even if asked.
  Inspect them as text instead. Do not assume a proposed Ansible operation is
  safe to run on the host; discuss potentially mutating or privileged actions
  before running them.
- Consider idempotence, check mode, privileges, existing user data, and the
  rpm-ostree deployment and reboot workflow when relevant. Point out limitations
  and suggest ways the user can validate each part safely.
