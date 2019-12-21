# Walkthrough of demo
### Peter Phan, pphan@hashicorp.com

---
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
name: packer
class: col-2
# Packer

I try to build as much as I can into my gold images and using Packer. This provides the following benefits:
- Consistent builds

--
- Faster deploy times

--
- Consistent images across various clouds
