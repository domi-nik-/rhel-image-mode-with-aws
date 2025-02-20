### How to use RHEL Image Mode on AWS

Prerequisites:

* AWS Account  
* RHEL Workstation/VM  
* Image Registry like quay.io  
* Preconfigured Github Account with ssh-key authentication  
* VSCodium or similar file editor

## What is the goal of the article?

Running an Web-App on a RHEL System on AWS behind an Elastic Loadbalancer.

## Services used:

* S3 for saving the RHEL Images and create AWS AMIs (Amazon Machine Images)  
* AWS ELB  
* “podman” for image creation, testing and pushing the generated AMIs  
* “cloud-init” for deploying the AMIs


## STEP 1 "Create github repo"

Create a github repo on github.com named "rhel-image-mode-with-aws".

 ```bash
cd $USERHOME #Change to $HOME
git clone git@github.com:$YOURGITHUBUSER/rhel-image-mode-with-aws.git
cd rhel-image-mode-with-aws #Change into our working directory
```




## Conclusion

Whast have we achieved?


## Why should I use “Image Mode”? Or what are the benefits of using it?

* Container Like behavior  
* Use DevOps Principles  
* Easy (automatic) upgrades and rollbacks  
* OStree based RHEL installs (one-time task)  
* Makes it also super easy for a fleet of Edge Devices