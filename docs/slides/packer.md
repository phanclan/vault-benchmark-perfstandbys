name: packer
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)

# Packer

![:scale 15%](images/HashiCorp_Icon_White.png)

---
class: compact

# Packer

[the components](#components)

I try to build as much as I can into my gold images and using Packer. This provides the following benefits:

- Consistent builds
- Faster deploy times
- Consistent images across various clouds

---
class: compact,col-2

# Packer Tips - What I Do

.smaller[
- I modify `install.sh`
  - Specify desired software versions.
- Then I run `packer build` on my json file `packer-hashistack.json`.
  - Capture the output of the image build to a file using the following command.]

```shell
packer validate template.json
packer inspect template.json
packer build packer-hashistack.json 2>&1 | tee /tmp/packer-output.txt
```

.smaller[
- Then you can extract the new AMI id to a file named `ami.txt` using the following command.]

```shell
tail -2 /tmp/packer-output.txt | head -2 | awk 'match($0, /ami-.*/) { print substr($0, RSTART, RLENGTH) }' > /tmp/ami.txt
```

.smaller[
- (optional) Delete your old AMI file
  - Login to AWS Console and select relevant AWS region.
  - Go to `EC2 > AMIs`. I filter by `pphan` which is part of my AMI tag for Name.
  - Select the AMI you want to delete. Note the creation date.
  - Delete the AMI: `Actions > Deregister`.
  - Go to `EC2 > Snapshots`. Filter by deleted AMI ID. Delete AMI Snapshot.
]

---
class: compact,col-2

My packer file build takes about 5.5 minutes to complete. Does the following.

.smaller[
- Builds an AWS image
  - ebs, hvm, ubuntu/images/*ubuntu-bionic-18.04-amd64-server-*, most_recent
- Runs the following scripts
  - install.sh
  - post.sh
]