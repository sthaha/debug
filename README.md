# Diagnostic Tool for DNS lookup #

## NOTE

Requires abilility to grand SCC `privileged` to `default` SA to run this tool.

## steps

1. apply the yaml file
2. daemonset won't start unless `default ` serviceaccount has privileged SCC
3. Grant `scc` `privileged` to `default` SA
  ```
    oc project dns-gather-tool
    oc admin policy add-scc-to-user -z default
  ```
4. Restart the `daemonset` (delete and reapply the file)

### TODO
- [ ] find a better way to bootstrap/deploy the tool
