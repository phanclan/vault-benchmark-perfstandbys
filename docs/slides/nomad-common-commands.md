class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Common Nomad Commands

## Peter Phan, pphan@hashicorp.com

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]
---
class: compact, col-2

```shell
nomad agent -config server.hcl > /tmp/nomad.log 2>&1 &
nomad operator raft list-peers
nomad node status

nomad job run <job_filename>
nomad job status <job_name>
nomad status <job_name> - similar to above
nomad job stop <job_name>
nomad job plan <job_filename> - job modification
nomad job run -check-index <index> <job_filename>

nomad alloc status <alloc_id>
```

