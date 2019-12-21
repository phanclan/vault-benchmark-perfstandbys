class: title, smokescreen, shelf, no-footer
background-image: url(https://story.xaprb.com/slides/adirondack/leo-serrat-533922-unsplash.jpg)

# Walkthrough of demo
### Peter Phan, pphan@hashicorp.com

---
name: components
# Components

This demo uses multiple HashiCorp products.
- Packer to build the images in AWS
- Terraform to provision the infrastructure
- Vault to demonstrate secrets management
- Nomad to run jobs

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: diagram
class: img-caption
# Diagram

---
name: img-right
class: img-right
![Yosemite](https://story.xaprb.com/slides/adirondack/leo-serrat-533922-unsplash.jpg)

Some text

---
name: getting-started
# Getting Started
- Set your variables in `scripts/env.sh`
- Run `00_fast_setup.sh`.
- Go to websites
  - http://consul.pphan.hashidemos.io:8500
  - http://vault-0.pphan.hashidemos.io:8200


---
name: packer
<!-- class: col-2 -->
# Packer
[the components](#components)

I try to build as much as I can into my gold images and using Packer. This provides the following benefits:
- Consistent builds

--
- Faster deploy times

--
- Consistent images across various clouds
