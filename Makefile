DESTDIR ?= /

.PHONY: dist
dist:
	mkdir -p build/etc/udev/rules.d/
	mkdir -p build/etc/dhcp/dhclient-exit-hooks.d/
	mkdir -p build/sbin/
	mkdir -p build/etc/network/
	mkdir -p build/etc/init/
	DEST=build make install
	chown -R 0:0 build
	tar -C build -czf dist.tgz .

.PHONY: modes
modes:
	chmod 644 53-ec2-network-interfaces.rules
	chmod 644 75-persistent-net-generator.rules
	chmod 644 ec2dhcp
	chmod 755 ec2ifscan
	chmod 755 ec2ifup
	chmod 755 ec2ifdown
	chmod 644 ec2net-functions
	chmod 755 ec2net.hotplug
	chmod 644 elastic-network-interfaces.conf
	chown 0:0 53-ec2-network-interfaces.rules
	chown 0:0 75-persistent-net-generator.rules
	chown 0:0 ec2dhcp
	chown 0:0 ec2ifup
	chown 0:0 ec2ifdown
	chown 0:0 ec2ifscan
	chown 0:0 ec2net-functions
	chown 0:0 ec2net.hotplug

.PHONY: install
install: modes
	cp -a 53-ec2-network-interfaces.rules $(DEST)/etc/udev/rules.d/
	cp -a 75-persistent-net-generator.rules $(DEST)/etc/udev/rules.d/
	cp -a ec2dhcp $(DEST)/etc/dhcp/dhclient-exit-hooks.d/
	cp -a ec2ifscan $(DEST)/sbin/
	cp -a ec2ifup $(DEST)/sbin/
	cp -a ec2ifdown $(DEST)/sbin/
	cp -a ec2net-functions $(DEST)/etc/network/
	cp -a ec2net.hotplug $(DEST)/etc/network/
	cp -a elastic-network-interfaces.conf $(DEST)/etc/init/
