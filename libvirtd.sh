#!/usr/bin/bash

set -xe

# HACK
# Use hosts's /dev to see new devices and allow macvtap
mkdir /dev.container && {
  mount --rbind /dev /dev.container
  mount --rbind /host-dev /dev

  # Keep some devices from the containerinal /dev
  keep() { mount --rbind /dev.container/$1 /dev/$1 ; }
  keep shm
  keep mqueue
  # Keep ptmx/pts for pty creation
  keep pts
  mount --rbind /dev/pts/ptmx /dev/ptmx
  # Use the container /dev/kvm if available
  [[ -e /dev.container/kvm ]] && keep kvm
}

mkdir /sys.net.container && {
  mount --rbind /sys/class/net /sys.net.container
  mount --rbind /host-sys/class/net /sys/class/net
}

mkdir /sys.devices.container && {
  mount --rbind /sys/devices /sys.devices.container
  mount --rbind /host-sys/devices /sys/devices
}

# If no cpuacct,cpu is present, symlink it to cpu,cpuacct
# Otherwise libvirt and our emulator get confused
if [ ! -d "/host-sys/fs/cgroup/cpuacct,cpu" ]; then
  echo "Creating cpuacct,cpu cgroup symlink"
  mount -o remount,rw /host-sys/fs/cgroup
  cd /host-sys/fs/cgroup
  ln -s cpu,cpuacct cpuacct,cpu
  mount -o remount,ro /host-sys/fs/cgroup
fi

mount --rbind /host-sys/fs/cgroup /sys/fs/cgroup

mkdir -p /var/log/kubevirt
touch /var/log/kubevirt/qemu-kube.log
chown qemu:qemu /var/log/kubevirt/qemu-kube.log
mkdir -p /etc/libvirt/qemu/networks/autostart

cat > /etc/libvirt/qemu/networks/bridge.xml <<EOX
<!--
WARNING: THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
OVERWRITTEN AND LOST. Changes to this xml configuration should be made using:
  virsh net-edit bridge
or other application using the libvirt API.
-->
<network>
  <name>bridge</name>
  <uuid>c6a08046-91fa-4e53-9813-f85b12350438</uuid>
  <forward dev='eth0' mode='route'>
    <interface dev='eth0'/>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:77:d0:55'/>
  <domain name='bridge'/>
  <ip address='10.0.1.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.0.1.2' end='10.0.1.2'/>
    </dhcp>
  </ip>
</network>
EOX

ln -s /etc/libvirt/qemu/networks/bridge.xml /etc/libvirt/qemu/networks/autostart/bridge.xml

cat > /etc/libvirt/qemu/generic.xml <<EOX
<!--
WARNING: THIS IS AN AUTO-GENERATED FILE. CHANGES TO IT ARE LIKELY TO BE
OVERWRITTEN AND LOST. Changes to this xml configuration should be made using:
  virsh edit generic
or other application using the libvirt API.
-->

<domain type='kvm'>
  <name>generic</name>
  <uuid>4d81803c-ae7e-4b2e-8f46-d65935e6fa79</uuid>
  <memory unit='KiB'>1048576</memory>
  <currentMemory unit='KiB'>1048576</currentMemory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-2.10'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <vmport state='off'/>
  </features>
  <cpu mode='custom' match='exact' check='partial'>
    <model fallback='allow'>Westmere</model>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/bin/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/centos7.0-devel.qcow2'/>
      <target dev='hda' bus='ide'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='usb' index='0' model='ich9-ehci1'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x7'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci1'>
      <master startport='0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0' multifunction='on'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci2'>
      <master startport='2'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x1'/>
    </controller>
    <controller type='usb' index='0' model='ich9-uhci3'>
      <master startport='4'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x2'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'/>
    <controller type='ide' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x1'/>
    </controller>
    <controller type='virtio-serial' index='0'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
    </controller>
    <interface type='network'>
      <mac address='52:54:00:eb:23:90'/>
      <source network='bridge'/>
      <model type='rtl8139'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='spicevmc'>
      <target type='virtio' name='com.redhat.spice.0'/>
      <address type='virtio-serial' controller='0' bus='0' port='1'/>
    </channel>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <sound model='ich6'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </sound>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </video>
    <redirdev bus='usb' type='spicevmc'>
      <address type='usb' bus='0' port='1'/>
    </redirdev>
    <redirdev bus='usb' type='spicevmc'>
      <address type='usb' bus='0' port='2'/>
    </redirdev>
    <memballoon model='virtio'>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
    </memballoon>
  </devices>
</domain>
EOX


#while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' 127.0.0.1:15000)" != "200" ]]; do sleep 5; done

#iptables -t nat -D PREROUTING 1

iptables -t nat -I PREROUTING 1 -p tcp -m comment --comment "Kubevirt Spice"  --dport 5900 -j ACCEPT
iptables -t nat -I PREROUTING 1 -p tcp -m comment --comment "Kubevirt virt-manager"  --dport 16509 -j ACCEPT

echo Start libvirt
/usr/sbin/virtlogd &
/usr/sbin/libvirtd -l
