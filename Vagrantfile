# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  ISOLATE_NETWORK = ENV["ISOLATE_NETWORK"] == "true"

  PROVISION_BEFORE_ISOLATION = "before-isolation"

  IP_NETWORK = "192.168.1."
  IP_GATEWAY = 1
  IP_ENTRYPOINT = 10
  IP_RANCHER_SERVER_BASE = 50
  IP_RANCHER_WORKER_BASE = 55

  GENERIC_BOX = "ubuntu/focal64"
  NETWORK_NAME="cloud-dev-env"

  config.vm.define "net-gateway" do |m|
    vm m, memory: 512, hostname: "net-gateway"
    internal_network m, ip(IP_GATEWAY)

    provision_docker m
    # TODO replace hardcoded interface
    m.vm.provision "shell", inline: <<-SHELL
      iptables -t nat -A POSTROUTING -o enp0s3 -j MASQUERADE
      sysctl net.ipv4.ip_forward=1
    SHELL
  end

  1.times { |idx|
    config.vm.define "rancher-server-#{idx}" do |m|
      vm m, memory: 1536, hostname: "rancher-server-#{idx}"
      internal_node_network m, ip(IP_RANCHER_SERVER_BASE + idx)
      provision_docker m
    end
  }
  2.times { |idx|
    config.vm.define "rancher-worker-#{idx}" do |m|
      vm m, cpus: 6, memory: 16384, disk_size: "100GB", hostname: "rancher-worker-#{idx}"
      internal_node_network m, ip(IP_RANCHER_WORKER_BASE + idx)
      provision_docker m
    end
  }

  config.vm.define "entrypoint" do |m|
    vm m, memory: 512, hostname: "entrypoint"
    internal_node_network m, ip(IP_ENTRYPOINT)

    m.vm.provision "file", source: ".vagrant/machines/rancher-server-0/virtualbox/private_key", destination: "server-0.key"
    m.vm.provision "file", source: ".vagrant/machines/rancher-worker-0/virtualbox/private_key", destination: "worker-0.key"
    m.vm.provision "file", source: ".vagrant/machines/rancher-worker-1/virtualbox/private_key", destination: "worker-1.key"
    m.vm.provision "file", source: "data/entrypoint/ssh-into", destination: "ssh-into"
    m.vm.provision "shell", inline: <<-SHELL
      echo "server-0 #{ip(IP_RANCHER_SERVER_BASE + 0)}"  > ./node-hosts
      echo "worker-0 #{ip(IP_RANCHER_WORKER_BASE + 0)}" >> ./node-hosts
      echo "worker-1 #{ip(IP_RANCHER_WORKER_BASE + 1)}" >> ./node-hosts
    SHELL
  end

  def internal_node_network(m, ip)
    internal_network m, ip

    #todo find a way for tagged provisioner execution
    #before_isolation_provision m, type: "shell", inline: "apt install -y net-tools iputils-tracepath"

    if ISOLATE_NETWORK then
      m.vm.network "forwarded_port", host: 2200, guest: 22, id: "ssh", disabled: true

      m.ssh.host = ip
      m.ssh.proxy_command = "ssh -i ./.vagrant/machines/net-gateway/virtualbox/private_key -W %h:%p -p 2222 -o LogLevel=FATAL -o Compression=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vagrant@127.0.0.1"

      m.vm.provider "virtualbox" do |vb|
        vb.customize "post-boot", ["controlvm", :id, "setlinkstate1", "off"]
      end

      m.vm.provision "shell", inline: <<-SHELL
        route add default gw #{ip(IP_GATEWAY)}
        #todo replace with net-gateway
        echo nameserver 8.8.8.8 > /etc/resolv.conf
      SHELL
    end
  end
  def internal_network(m, ip)
     m.vm.network "private_network", ip: ip, virtualbox__intnet: NETWORK_NAME

  end

  def vm(m, cfg = {})
    m.vm.box = cfg.fetch(:box, GENERIC_BOX)
    m.vm.provider "virtualbox" do |vb|
      vb.memory = cfg.fetch(:memory, 512)
      vb.cpus = cfg.fetch(:cpus, 2)
    end
    m.vm.hostname = cfg.fetch(:hostname, "vagrant-host")
    m.vm.disk :disk, size: cfg.fetch(:disk_size), primary: true if cfg.include?(:disk_size)

    m.vm.synced_folder ".", "/vagrant", disabled: true

    m.vm.graceful_halt_timeout = 300
    m.vm.boot_timeout = 600

    provision_default m
  end

  def ip(ip)
    return "#{IP_NETWORK}#{ip}"
  end

  def provision_default(m)
    before_isolation_provision m, type: "shell", inline: "apt update -y && apt upgrade -y && apt install -y net-tools iputils-tracepath"
  end
  def provision_docker(m)
    m.vm.provision "shell", inline: <<-SHELL
      apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common && \
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" && \
      apt update -y && apt install -y docker-ce docker-ce-cli containerd.io
    SHELL
  end

  def before_isolation_provision(m, args)
    m.vm.provision PROVISION_BEFORE_ISOLATION, { :run => "never"}.merge!(args)
  end

end
