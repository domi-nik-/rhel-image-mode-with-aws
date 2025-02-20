FROM registry.redhat.io/rhel9/rhel-bootc:9.5

#install the lamp components
RUN dnf module enable -y nginx:1.24 && dnf install -y httpd cloud-init && dnf clean all

#start the services automatically on boot
RUN systemctl enable httpd