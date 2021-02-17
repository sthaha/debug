# Diagnostic Tool for DNS lookup #

## NOTE

Requires abilility to grand SCC `privileged` to `default` SA to run this tool.

## Usage

1. Edit the `dns-gather-tool.yaml` file to add the hosts
1. Apply the yaml - `oc apply -f dns-gather-tool.yaml`
1. daemonset won't start unless `default ` serviceaccount has privileged SCC
1. Grant `scc` `privileged` to `default` SA
  ```
    oc project dns-gather-tool
    oc admin policy add-scc-to-user -z default
  ```
1. Restart the `daemonset`
  - ``oc delete daemonset/dns-gather-tool``
  - ``oc apply -f dns-gather-tool.yaml``


This should start the daemonset and will start collecting dns lookup info. All
sucessfull lookups will be ignored and only the failed ones will be collected.

Use `gather-diagnostic-info.sh` to copy the data to your local machine for
further analysis.


### How it works

### TODO
- [ ] find a better way to bootstrap/deploy the tool
- [ ] Add verbose usage info
- [ ] Add How it works section
