#!/usr/bin/env bash

set -e

for host in $(find -maxdepth 1 -type d); do
	SSH_HOST_DIR="$host/etc/ssh"
	mkdir -p "$SSH_HOST_DIR"
	rm -f "$SSH_HOST_DIR"/ssh_host_*
	for key_type in dsa ecdsa ed25519 rsa; do
		ssh-keygen -N '' -t $key_type -f "$SSH_HOST_DIR/ssh_host_${key_type}_key"
	done

	SSH_USER_DIR="$host/home/vagrant/.ssh"
	mkdir -p "$SSH_USER_DIR"
	rm -f "$SSH_USER_DIR"/{id_rsa,id_rsa.pub}
	ssh-keygen -N '' -f "$SSH_USER_DIR/id_rsa"
	mv "$SSH_USER_DIR/id_rsa.pub" "$SSH_USER_DIR/authorized_keys"
done
