# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  ISOLATE_NETWORK = ENV["ISOLATE_NETWORK"] == "true"

  PROVISION_BEFORE_ISOLATION = "before-isolation"

  IP_NETWORK = "192.168.1."
  IP_GATEWAY = 1

  GENERIC_BOX = "ubuntu/focal64"
  NETWORK_NAME = "cloud-dev-env"

  config.vm.define "net-gateway" do |m|
    vm m, memory: 512, hostname: "net-gateway", ip: ip(IP_GATEWAY)

    # TODO replace hardcoded interface, move provisioning to vm
    m.vm.provision "shell", run: "always", inline: <<-SHELL
      iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
      iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
      sysctl net.ipv4.ip_forward=1
    SHELL

    provision_host_directory m, "data/net-gateway"
    provision_host_directory m, "secrets/net-gateway"
    m.vm.provision "shell", inline: <<-SHELL
      chown -R vagrant:vagrant /home/vagrant && find /home/vagrant/.ssh/ -type f | xargs chmod 0600
    SHELL

    m.vm.provision "shell", inline: <<-SHELL
      apt install -y --download-only dnsmasq && \
      apt install -y dnsmasq && \
      echo nameserver 127.0.0.1 > /etc/resolv.conf && \
      systemctl stop dnsmasq && mv dnsmasq.conf /etc/dnsmasq.conf && systemctl restart dnsmasq && \
      apt install -y openconnect inotify-tools
    SHELL

  end

  1.times { |idx|
    config.vm.define "rancher-server-#{idx}" do |m|
      vm m, memory: 8192, hostname: "rancher-server-#{idx}", internal_node: true
      provision_rancher_server m
    end
  }
  2.times { |idx|
    config.vm.define "rancher-worker-#{idx}" do |m|
      vm m, cpus: 6, memory: 16384, disk_size: "100GB", hostname: "rancher-worker-#{idx}", internal_node: true
      provision_rancher_agent m
    end
  }

  config.vm.define "entrypoint" do |m|
    vm m, memory: 512, hostname: "entrypoint", internal_node: true

    m.vm.provision "file", source: ".vagrant/machines/rancher-server-0/virtualbox/private_key", destination: "rancher-server-0.key"
    m.vm.provision "file", source: ".vagrant/machines/rancher-worker-0/virtualbox/private_key", destination: "rancher-worker-0.key"
    m.vm.provision "file", source: ".vagrant/machines/rancher-worker-1/virtualbox/private_key", destination: "rancher-worker-1.key"
    m.vm.provision "file", source: "data/entrypoint/ssh-into", destination: "ssh-into"
  end

  def internal_node_network(m, host_name)
    internal_network m

    if ISOLATE_NETWORK then
      m.vm.network "forwarded_port", host: 2200, guest: 22, id: "ssh", disabled: true

      m.ssh.host = host_name
      m.ssh.proxy_command = "ssh -i ./.vagrant/machines/net-gateway/virtualbox/private_key -W %h:%p -p 2222 -o LogLevel=FATAL -o Compression=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@127.0.0.1"

      m.vm.provider "virtualbox" do |vb|
        vb.customize "post-boot", ["controlvm", :id, "setlinkstate1", "off"]
      end
    end
  end
  def internal_network(m, cfg = {})
    net_cfg = { :virtualbox__intnet => NETWORK_NAME }

    if cfg.include?(:ip) then
      net_cfg[:ip] = cfg.fetch(:ip)
    else
      net_cfg[:auto_config] = false
    end

    m.vm.network "private_network", net_cfg
  end

  def vm(m, cfg = {})
    m.vm.box = cfg.fetch(:box, GENERIC_BOX)
    m.vm.provider "virtualbox" do |vb|
      vb.memory = cfg.fetch(:memory, 512)
      vb.cpus = cfg.fetch(:cpus, 2)
    end
    m.vm.hostname = cfg.fetch(:hostname)
    m.vm.disk :disk, size: cfg.fetch(:disk_size), primary: true if cfg.include?(:disk_size)

    m.vm.synced_folder ".", "/vagrant", disabled: true

    m.vm.graceful_halt_timeout = 300
    m.vm.boot_timeout = 600

    if cfg.fetch(:internal_node, false) then
      internal_node_network m, cfg.fetch(:hostname)
      additional_script = "(apt install -y dhcpcd5 && echo 'allowinterfaces enp*' >> /etc/dhcpcd.conf)"
    else
      internal_network m, ip: cfg.fetch(:ip)
      additional_script = ""
    end

    m.vm.provision PROVISION_BEFORE_ISOLATION, run: "never", type: "shell", inline: <<-SHELL
      apt update -y && apt upgrade -y && apt install -y net-tools iputils-tracepath #{if !additional_script.empty? then "&& " + additional_script else "" end} &&
      systemctl disable multipathd && systemctl stop multipathd &&
      systemctl disable systemd-resolved && systemctl stop systemd-resolved &&
        rm /etc/resolv.conf && echo nameserver 8.8.8.8 > /etc/resolv.conf
    SHELL
  end

  def ip(ip)
    return "#{IP_NETWORK}#{ip}"
  end

  def provision_rancherd(m, config_name)
    provision_host_directory m, "data/rancher/config-#{config_name}"
    m.vm.provision "shell", inline: <<-SHELL
      curl -sfL https://get.rancher.io | sh -
    SHELL
  end
  def provision_rancher_server(m)
    provision_rancherd m, "server"
    m.vm.provision "shell", inline: <<-SHELL
      function retry_until_success() {
        local command="$1"
        local message="${2:-retrying $1}"
        while ! eval "$command"; do sleep 5; echo "$message"; done
      }
      snap install kubectl --classic && bash <(curl -sL  https://www.eclipse.org/che/chectl/) &&
      systemctl enable rancherd-server.service && systemctl start rancherd-server.service &&
        retry_until_success "nc -z localhost 443" "waiting for rancher-server" &&
        retry_until_success "rancherd reset-admin --password cloud" "retrying ui init" &&
      mkdir /home/vagrant/.kube && mkdir /root/.kube/ &&
        cp /etc/rancher/rke2/rke2.yaml /home/vagrant/.kube/config &&
        cp /etc/rancher/rke2/rke2.yaml /root/.kube/config &&
        chown -R vagrant:vagrant /home/vagrant &&
      kubectl apply -f /home/vagrant/rancher/
    SHELL
  end
  def provision_rancher_agent(m)
    provision_rancherd m, "agent"
    m.vm.provision "shell", inline: <<-SHELL
      systemctl enable rancherd-agent.service &&
      systemctl start rancherd-agent.service
    SHELL
  end

  def provision_host_directory(m, host_directory)
    m.vm.provision "file", source: host_directory, destination: "/tmp/file-provision"
    m.vm.provision "shell", inline: <<-SHELL
      for f in $(find /tmp/file-provision/ -mindepth 1 -maxdepth 1); do
        cp -r $f /
      done &&
      rm -rf /tmp/file-provision
    SHELL

  end

end
