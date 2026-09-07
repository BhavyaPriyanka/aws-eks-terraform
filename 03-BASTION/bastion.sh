#!/bin/bash

set -e

USERID=$(id -u)
TIMESTAMP=$(date +%F-%H-%M-%S)
SCRIPT_NAME=$(basename "$0" .sh)
LOGFILE="/tmp/${SCRIPT_NAME}-${TIMESTAMP}.log"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

# Send output to both screen and logfile
exec > >(tee -a "$LOGFILE") 2>&1

VALIDATE() {
    if [ "$1" -ne 0 ]; then
        echo -e "$2...$R FAILURE $N"
        exit 1
    else
        echo -e "$2...$G SUCCESS $N"
    fi
}

if [ "$USERID" -ne 0 ]; then
    echo "Please run this script with root access."
    exit 1
else
    echo "You are super user."
fi

echo "========================================="
echo " Bastion Host Setup"
echo " Amazon Linux 2023"
echo "========================================="


# ---------------------------------------------------------
# System update
# ---------------------------------------------------------

dnf update -y
VALIDATE $? "System update"


# ---------------------------------------------------------
# Basic packages
# ---------------------------------------------------------

dnf install -y \
    wget \
    unzip \
    tar \
    gzip \
    git \
    jq \
    mariadb105

VALIDATE $? "Basic packages installation"


# ---------------------------------------------------------
# Docker
# ---------------------------------------------------------

dnf install -y docker
VALIDATE $? "Docker installation"

systemctl enable --now docker

usermod -aG docker ec2-user

echo -e "Docker setup...$G SUCCESS $N"


# ---------------------------------------------------------
# kubectl
# EKS Kubernetes version = 1.32
# ---------------------------------------------------------

KUBECTL_VERSION="v1.32.13"

curl -Lo /usr/local/bin/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

chmod +x /usr/local/bin/kubectl

kubectl version --client

VALIDATE $? "kubectl installation"


# ---------------------------------------------------------
# eksctl
# ---------------------------------------------------------

ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl --silent --location \
    "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz" \
    | tar xz -C /tmp

mv /tmp/eksctl /usr/local/bin/eksctl

eksctl version

VALIDATE $? "eksctl installation"


# ---------------------------------------------------------
# Helm
# ---------------------------------------------------------

curl -fsSL \
    -o /tmp/get_helm.sh \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 /tmp/get_helm.sh

/tmp/get_helm.sh

helm version

VALIDATE $? "Helm installation"


# ---------------------------------------------------------
# kubectx / kubens
# ---------------------------------------------------------

rm -rf /opt/kubectx

git clone \
    https://github.com/ahmetb/kubectx \
    /opt/kubectx

ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx

kubens --help >/dev/null
kubectx --help >/dev/null

VALIDATE $? "kubectx and kubens installation"


# ---------------------------------------------------------
# Final verification
# ---------------------------------------------------------

echo
echo "========================================="
echo " Installation Summary"
echo "========================================="

echo
echo "AWS CLI:"
aws --version

echo
echo "kubectl:"
kubectl version --client

echo
echo "eksctl:"
eksctl version

echo
echo "Helm:"
helm version

echo
echo "MySQL:"
mysql --version

echo
echo "Docker:"
docker --version

echo
echo "kubens:"
kubens --help | head -5

echo
echo "========================================="
echo -e "$G Bastion setup completed successfully $N"
echo "Log file: $LOGFILE"
echo "========================================="