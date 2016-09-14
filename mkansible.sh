#!/bin/env bash

#
# Automatically Create an ANSIBLE INVENTORY file base on a AWSCLI query
#
# Written by jdelatorre - jorgedlt@gmail.com - 13 SEP 2016

# Note: This script only creates host which powerup at runtime

[[ -f /usr/bin/aws ]] && : || { echo aws-cli not found; exit 1 ; }

# make an archive copied of the previous inventory file
[[ -f ansible.inv ]] && cp -f ansible.inv ansible.keep.$(date +"%Y%m%d")

horz () {
  # automatically creates an ansible header ... like [webservers]

  # Find the longest Line
    lLEN=$(cat ansible.tmp | awk '{print length, $0}'|sort -nr|head -1 | awk '{print $1}')
    printf '# %*s\n' "${lLEN}" '' | tr ' ' -  > ansible.h$1
    printf '[%s]\n' "$1"   >> ansible.h$1

    [[ -f ansible.horz ]] && : || { printf '# %*s\n' "${lLEN}" '' | tr ' ' -  > ansible.horz ; }
}

pemFILE=$(ls *.pem)

# Get AWS RAW List -- exclude - 'slave|termi|stop|Alert|Logic|bastion'
aws ec2 describe-instances --query \
'Reservations[*].Instances[*].[Tags[?Key==`Name`].Value[],InstanceId,State.Name,InstanceType,PrivateIpAddress,PublicIpAddress]' \
--output text | awk 'NR%2{printf "%s ",$0;next;}1' | column -t | sort > awsls.raw

# Get AWS List -- exclude - 'slave|termi|stop|Alert|Logic|bastion'
cat awsls.raw | egrep -iv 'slave|termi|stop|alert|logic|bastion' > awsls.dump

# Check for a clean file
[[ $( cat awsls.dump | grep -v '^i' | wc -l | tr -s ' ' ) -eq 0 ]] && : || { echo dump broke; cat awsls.dump; exit 1 ; }

cat awsls.dump | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep ^10 > aws.ipAddr.list
cat awsls.dump | awk '{print $6}' | tr 'A-Z' 'a-z' > aws.hosts.list

for ipAddr in $(cat aws.ipAddr.list); do
  hname=$(grep $ipAddr ./awsls.dump | tr -s ' '| tr 'A-Z' 'a-z' |  awk -F " " '{print $NF}')
  echo $hname ansible_host=$ipAddr ansible_ssh_private_key_file=~/${pemFILE} ansible_ssh_user=ubuntu
done > ansible.raw

# Purge Bastion Host as redundant
  cat ansible.raw | grep -iv bastion > ansible.tmp
# Find the CORE
  cat ansible.tmp | grep -i core | sort > ansible.core
  horz core
# Find the AUTH
  cat ansible.tmp | grep -i auth | sort > ansible.auth
  horz auth
# Find the REST
  cat ansible.tmp | egrep -vi 'core|auth' | sort > ansible.rest
  horz rest

#
echo $pemFILE | tr -d 'a-z' | tr -sc 'A-Z' | sed 's/^-//' | sed 's/\.$//' | figlet | sed 's/^/# /g' > ansible.head
cat awsls.raw | sed 's/^i-/# i-/g' >> ansible.awsls

echo \# >> ansible.awsls
echo -e \# "\0176   \0176" NOTE: Some servers on the FULL list DO NOT appear on the INVENTORY file. >> ansible.awsls
echo -e \# "\0176   \0176" Any hostnames with REGEX \\'slave|termi|stop|alert|logic|bastion\' are skipped. >> ansible.awsls
echo \# >> ansible.awsls

# Put back together
cat  ansible.horz ansible.head ansible.hcore ansible.core ansible.hauth ansible.auth ansible.hrest ansible.rest ansible.horz ansible.awsls ansible.horz > ansible.tmp

# Add Date at the top
echo \# Ansible Inventory Created: "$(date)" 'for' $(echo $pemFILE | tr -d 'a-z' |
 tr -sc 'A-Z' | sed 's/^-//' | sed 's/\.$//' ) environment > ansible.inv
cat ansible.tmp >> ansible.inv

# Add Examples at the bottom
/bin/echo -e \# Usage Examples\; "\n"\# ansible -i ansible.inv -m shell -a \'w\' core >> ansible.inv
/bin/echo -e \# ansible -i ansible.inv -m shell -a \'df -kh\' all >> ansible.inv
cat ansible.horz >> ansible.inv

# clean up
rm -r aws.hosts.list aws.ipAddr.list ansible.tmp ansible.core ansible.auth ansible.rest
rm -r ansible.hauth ansible.hcore ansible.horz ansible.hrest ansible.raw ansible.awsls
rm -f awsls.dump ansible.head awsls.raw

cat ansible.inv

exit 0
