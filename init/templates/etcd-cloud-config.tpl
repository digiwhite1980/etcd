#cloud-config

package_upgrade: true

packages:
  - docker.io
  - bridge-utils
  - socat
  - ntp

datasource:
  Ec2:
    timeout : 50
    max_wait : 120
    metadata_urls:
      - http://169.254.169.254:80

write_files:
  - path: /etc/systemd/system/etcd.service
    content: |
      [Unit]
      Description=etcd 3.2.2 service (Digiwhite)
      Requires=docker.service
      After=docker.service
      [Service]
      ExecStartPre=-/usr/bin/docker pull digiwhite/etcd:3.2.2
      ExecStart=/usr/bin/docker run \
        -h etcd \
        --net=host \
        --name=etcd \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --rm \
        -e ETCD_AUTO_TLS=1 \
        -e ETCD_PEER_AUTO_TLS=1 \
        digiwhite/etcd:3.2.2
      ExecStop=/usr/bin/pkill etcd
      [Install]
      WantedBy=multi-user.target

  - path: /etcd/ssl/client.crt
    owner: root:root
    encoding: base64
    content: "${base64encode("${ssl_client_cert}")}"

  - path: /etcd/ssl/client.key
    owner: root:root
    permissions: '0400'
    encoding: base64
    content: "${base64encode("${ssl_client_key}")}"

  - path: /etcd/ssl/client_ca.crt
    owner: root:root
    encoding: base64
    content: "${base64encode("${ssl_ca_cert}")}"

  - path: /etcd/ssl/peer.crt
    owner: root:root
    encoding: base64
    content: "${base64encode("${ssl_client_cert}")}"

  - path: /etcd/ssl/peer.key
    owner: root:root
    permissions: '0400'
    encoding: base64
    content: "${base64encode("${ssl_client_key}")}"

  - path: /etcd/ssl/peer_ca.crt
    owner: root:root
    encoding: base64
    content: "${base64encode("${ssl_ca_cert}")}"

runcmd:
  - [ systemctl, enable, docker ]
  - [ systemctl, start, docker ]
  - [ systemctl, enable, etcd ]
  - [ systemctl, start, etcd ]
