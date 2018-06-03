# infra/config branch

This branch contains WebRTC project-wide configurations for chrome infra
services.

For example, [cr-buildbucket.cfg](cr-buildbucket.cfg) defines builders.

## Making changes

It is recommended to have a separate checkout for this branch, so switching
to/from it does not populate/delete all files in the master branch.

Initial setup:

```bash
git clone https://webrtc.googlesource.com/src/ -b infra/config --single-branch config
cd config
git config depot-tools.upstream origin/infra/config
```

Now you can create a new branch to make changes:

```bash
git new-branch add-new-builder
# edit files
git commit -a
git cl upload
```

Changes can be reviewed on Gerrit and submitted with commit queue as usual.

### Activating the changes

Any changes to this directory go live soon after landing, without any additional
steps. You can see the status or force a refresh of the config at
[luci-config](https://luci-config.appspot.com/#/projects/webrtc).
