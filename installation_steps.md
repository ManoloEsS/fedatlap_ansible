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
   "$HOME/.local/bin/mise" exec -- ansible-galaxy collection install -r requirements.yml
   ```

3. Run the pre-deployment playbook locally. Ansible will prompt for your sudo
   password when needed:

   ```sh
   "$HOME/.local/bin/mise" exec -- ansible-playbook -i inventory.ini -c local --ask-become-pass pre-deployment-playbook.yaml
   ```

If the playbook reports that a reboot is needed, reboot before proceeding to
post-deployment configuration.
