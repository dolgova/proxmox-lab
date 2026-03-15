[web_nodes]
%{ for i, node in nodes ~}
${node.name} ansible_host=192.168.1.${101 + i} ansible_user=root ansible_ssh_private_key_file=~/.ssh/proxmox-lab ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{ endfor ~}
[web_nodes:vars]
ansible_python_interpreter=/usr/bin/python3
