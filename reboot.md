# Reboot Policy in DM

- See the `sites/test-site/groups.yml` for the example of the data model edits to include reboot policy details. The hope is that everything we would need for boot policy would live in the same file so it's easy to find the entire reboot policy.

Influenced by what I've seen in [virtualbox docs](https://www.virtualbox.org/manual/ch08.html) `--nicbootprio` is a number that specifies which NIC should be booted first.

## Requirements

1. Group by node type, with limit on # of concurrent nodes rebooted, ordered by groups. (Works for Kubernetes -- masters then minions, no more than X at once.)
2. Explicitly ordered reboots for certain clusters -- for example: [ instance1, instance3, instance2, instance5, instance4, instance6 ]. (Works for MemSQL.)


## New Data Model Fields

### Fields for `host_group` and `host`

More specificity will always take precedence.

- `boot_prio`: is an integer field that could be under a host_group or an individual host. Vaquero will order priority from lowest to highest. A `boot_prio` =: 0 will be booted before a `boot_prio` of 1. If the `boot_prio` of different groups or nodes have the same score, the order of booting will happen in any order within that boot group. One can think of a decimal number, `<group_bootP>.<host_bootP>` we will boot from lowest to highest, ties have no guaranteed order. Default is 0.

- `flush_pipeline`: the pipeline of containers to execute before shutting down a machine. This is exactly like `drone.yml`, the intent is that we will run containers from top to bottom, only proceeding to the next container if the prior passed. Not declaring a `flush_pipeline` would indicate vaquero can shut down the host without taking any actions.

- `resurrect_pipeline`: the pipeline of containers to execute after a reboot. This is exactly like `drone.yml`, the intent is that we will run containers from top to bottom, only proceeding to the next container if the prior passed. Not declaring a `resurrect_pipeline` would indicate vaquero can bring up the host without taking any actions.

## Fields for `host_group` only

- `max_concurrent`: an integer or percentage of max number of machines that could reboot at one time. For percentage we will round down, the last batch will be the remainder. A value of 0 would mean all machines can be rebooted at the same time, conversely a percentage of 100% could do the same. Default is 1.

## Concerns:

- Private docker registry, might need more details. URL, User, Password. See how [Drone Docs](http://readme.drone.io/usage/build_test/) handles this.
- Don't want to clutter the data model, but don't want to make people re-write the host_groups and hosts to specify BMC options. Regardless, all the BMC details should be explicit and live in one file. We could have another `policy.yml` butin that document you would have to type every host_group / host you'd want included in the policy.
- How exactly does one flush / resurrect from the vaquero agent. (Need to ssh or something into a given machine and we will look at exit codes to decide if a step in the pipeline was a success or failure. `os.Exit(0) = success` and `os.Exit(1) = failure`)
