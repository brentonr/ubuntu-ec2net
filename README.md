ubuntu-ec2net
=============

Fork of bkr/ubuntu-ec2net to add support for routing of ENIs on the same subnet
and docker routing support to allow published ports from a container to the host
to be served by both ENIs.

Port of Amazon's ec2-net-utils scripts to Debian/Ubuntu for automatically
configuring additional AWS Elastic Network Interfaces.

Amazon's description of these tools:

http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html#ec2-net-utils

Launchpad Bug:

https://bugs.launchpad.net/cloud-init/+bug/1153626/

Some discussion of the problem:

http://blog.bluemalkin.net/multiple-ips-and-enis-on-ec2-in-a-vpc/

Use the Makefile to install the files.


Add an interface by hand
========================

To configure `eth1`, for example:

    env INTERFACE=eth1 ACTION=add /etc/network/ec2net.hotplug add

Note that this configuration will survive a reboot.


General Background with Docker
==============================
The `53-ec2-network-interfaces.rules` udev rules will allow an interface to be hotplugged in and out of the EC2 Linux OS.

On hotplug in, the `ec2net.hotplug` script is executed to configure the interface. Following this, `ifup` will be executed on the interface to bring it up with the configuration written by `ec2net.hotplug`.

On removal, `ifdown` is executed on the interface, but the configuration is kept in tact.

Because this is adding another ENI on the same subnet, policy-based routing is used to create a separate routing table specific to the ENI, instead of relying upon the default system-wide routing table. This unique routing table allows the ENI to have it's default gateway use the ENI, which is separate from the default system-wide table which routes traffic out the default (usually `eth0`) interface.

Traffic coming in to the ENI will be marked using `iptables` FW marks, so that packets responding to requests into a docker container can be routed to the interface-specific routing table, and thus be sent back out using the ENI instead of the default system routing table (which typically uses `eth0`).

When an interface is configured (on hotplug in), the `/etc/network/interfaces.d/eth${INDEX}.cfg` file is written with contents:

* configuration for DHCP and a metric value matching 1000 + ${INDEX}
* `post-up` commands that add a separate routing table for the interface along with `iptables` rules to mark traffic coming in on that interface with a unique marker. This is used later with docker to allow the correct routing of packets back out the interface they came in on.
* `post-up` commands that wait for the docker0 bridge to become stable (during startup) to add a route to docker0 in the interface-specific routing table
* 'pre-down` to remove the docker0 route from the interface-specific routing table

Once this is complete, `ifup` will execute the `post-up` commands in the `/etc/network/interfaces.d/eth${INDEX}.cfg` file. The DHCP client is launched, which has a `dhclient-exit-hook` to be run after the DHCP client configures an interface with an obtained IP address or when the DHCP client deconfigures an interface.

When configuring an interface, this hook script will:

* Ensure routing rules are current for the configured interface. This includes removing stale entries that no longer apply.
* Adds a routing rule that matches all FW marks in incoming packets to use the interface-specific routing table. This is used to route packets going out of a docker container to make sure they use the interface-specific routing table, and thus leave going out the specific interface.

When deconfiguring an interface, this hook script will:

* Remove routing rules for the deconfigured interface

Finally, to work correctly with startup conditions in `upstart`, several scripts are used:

* `elastic-network-interfaces.conf` will start only once `eth0` is up, so that the IMDS can be used with the above scripts. Once `eth0` is up, `ec2ifupscan` is called which attemps to re-send udev events for any ENIs attached, which triggers the udev rules above.
* `docker-finish.conf` which adds `iptables` rules on the docker0 interface to effectively transfer incoming packets' FW marks to their outgoing responses. This script depends on docker having started to ensure the `docker0` bridge is active and can be referenced in the `iptables` rules.

