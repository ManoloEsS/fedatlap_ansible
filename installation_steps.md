# Installation steps

Run these steps as your regular user from the root of this repository on the
Fedora Silverblue workstation. The Mise bootstrap requires network access and
installs the tools declared in `mise.toml`.

1. Install Mise and the declared tools:

   ```sh
   bash scripts/bootstrap-mise.sh
   ```

2. Install the required Ansible collection to your user account:

   ```sh
   "$HOME/.local/bin/mise" exec -- ansible-galaxy collection install -r deployments/requirements.yml
   ```

3. Run the pre-deployment playbook locally. Ansible will prompt for your sudo
   password when needed:

   ```sh
   "$HOME/.local/bin/mise" exec -- ansible-playbook -c local --ask-become-pass deployments/pre-deployment-playbook.yaml
   ```

4. If the playbook reports that a reboot is needed, reboot before proceeding.

5. Run the post-deployment playbook from the repository root:

   ```sh
   "$HOME/.local/bin/mise" exec -- ansible-playbook -c local --ask-become-pass deployments/post-deployment-playbook.yaml
   ```

   The playbook prompts for a keyd keyboard ID, optional battery threshold
   setup, and trusted network UUIDs. An empty keyd response applies the remap
   to all keyboards. It also applies Mise dotfiles with force, replacing
   conflicting files without backups. Firewall changes may interrupt an SSH
   connection. The playbook completed on one target; a fully fresh installation
   has not yet been validated end-to-end.

6. Optional: enable automatic login after confirming that Niri is selected and
   works at the GDM login screen. Edit `/etc/gdm/custom.conf` with administrator
   privileges and set `AutomaticLoginEnable=True` and `AutomaticLogin` to your
   username under the existing `[daemon]` section. Avoid duplicate settings or
   duplicate `[daemon]` sections, then reboot to test.

   Automatic login permits physical access to your account without a login
   password and may leave the login keyring locked until separately unlocked.
