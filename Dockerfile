FROM fedora:27

MAINTAINER "The KubeVirt Project" <kubevirt-dev@googlegroups.com>
ENV container docker

# nettle update is necessary for dnsmasq which is used by libvirt
RUN dnf -y update nettle && \
  dnf install -y \
  libvirt-daemon-kvm \
  libvirt-client \
  net-tools \
  multitail \
  libcap \
  libcap-devel \
  iptables \
  tcpdump \
  nmap-ncat \
  selinux-policy selinux-policy-targeted \
  augeas && dnf clean all

COPY augconf /augconf
RUN augtool -f /augconf

COPY qemu.conf /etc/libvirt/qemu.conf

COPY libvirtd.sh /libvirtd.sh
RUN chmod a+x /libvirtd.sh

CMD ["/libvirtd.sh"]
