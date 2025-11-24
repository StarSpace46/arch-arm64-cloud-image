#!/bin/bash
set -e
echo "=== Upgrading system and installing packages ==="

# Update system
pacman -Syu --noconfirm

# Install essential packages
pacman -S --noconfirm \
    base-devel \
    git \
    openssh \
    sudo \
    curl \
    wget \
    vim \
    htop \
    grub \
    efibootmgr \
    dosfstools \
    networkmanager \
    python \
    python-pip \
    python-yaml \
    python-jinja \
    python-jsonschema \
    python-requests \
    python-oauthlib \
    python-configobj \
    python-netifaces \
    python-jsonpatch

echo "=== Packages installed successfully ==="
