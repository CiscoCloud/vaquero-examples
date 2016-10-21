# Reboot Policy in DM

- See the `sites/test-site/groups.yml` for the example of the data model edits to include reboot policy details. The hope is that everything we would need for boot policy would live in the same file so it's easy to find the entire reboot policy. We will attempt to replicate as much of the [drone](https://github.com/drone/drone) workflow when it comes to executing pipelines.

## Requirements

1. Group by node type, with limit on # of concurrent nodes rebooted, ordered by groups. (Works for Kubernetes -- masters then minions, no more than X at once.)
2. Explicitly ordered reboots for certain clusters -- for example: [ instance1, instance3, instance2, instance5, instance4, instance6 ]. (Works for MemSQL.)


## New Data Model Fields

### Fields for `host_group` and `host`

- `flush_pipeline`: the pipeline of containers to execute before shutting down a machine. This is exactly like `drone.yml`, the intent is that we will run containers from top to bottom, only proceeding to the next container if the prior passed. Not declaring a `flush_pipeline` would indicate vaquero can shut down the host without taking any actions. Default: empty

- `validate_pipeline`: the pipeline of containers to execute after a reboot. This is exactly like `drone.yml`, the intent is that we will run containers from top to bottom, only proceeding to the next container if the prior passed. Not declaring a `validate_pipeline` would indicate vaquero can bring up the host without taking any actions. Default: empty

## Fields for `host_group` only

- `max_concurrent`: an integer or percentage of max number of machines that could reboot at one time. For percentage we will round down, the last batch will be the remainder. A value of 0 would mean all machines can be rebooted at the same time, conversely a percentage of 100% could do the same. Default is 1.

- `safe_deps`: a list of dependencies that this host group has and can concurrently boot with. Default: empty

- `block_deps`: a list of dependencies that this host group must wait for its completion to begin its booting process. Default: empty

- `val_on_deps`: a list of dependencies that this host_group should run its `validate_pipeline` given a dependency in this list is changed. Default: empty

- `max_fail`: the maximum number or percentage of machines that is considered an acceptable failure rate. This is just to protect one machine hardware failure from blocking the entire update. Default: 0

## Fields for `host` only

- `boot_number`: the integer that specifies the booting order of the hosts in the group. We will boot from lowest to highest, ties will boot in any order. Default: 0

## Concerns:

- Private docker registry, might need more details. URL, User, Password. See how [Drone Docs](http://readme.drone.io/usage/build_test/) handles this.
- Don't want to clutter the data model, but don't want to make people re-write the host_groups and hosts to specify BMC options. Regardless, all the BMC details should be explicit and live in one file.
- How exactly does one flush / resurrect from the vaquero agent. (Need to ssh or something into a given machine and we will look at exit codes to decide if a step in the pipeline was a success or failure. `os.Exit(0) = success` and `os.Exit(1) = failure`) We need to capture the log output from that container.
