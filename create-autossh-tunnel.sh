#!/bin/bash

declare from_ip="${FROM_IP:-0.0.0.0}"
declare from_port="${FROM_PORT:-9999}"
declare to_ip="${TO_IP}"
declare to_port="${TO_PORT}"
declare ssh_key="${SSH_KEY}"
declare username="${USERNAME}"
declare jumphost="${JUMPHOST}"

# We need TEMP as the 'eval set --' would nuke the return value of getopt.
TEMP="$(getopt -o '' --long 'jumphost:,username:,from-port:,from-ip:,to-port:,to-ip:,ssh-key:' -- "$@")"

if [ $? -ne 0 ]; then
  echo 'Terminating...' >&2
  exit 1
fi

# Note the quotes around "$TEMP": they are essential!
eval set -- "$TEMP"
unset TEMP

# process args
while true; do
  case "$1" in
    '--jumphost')
      jumphost="$2"
      ;;
    '--username')
      username="$2"
      ;;
    '--from-ip')
      from_ip="$2"
      ;;
    '--from-port')
      from_port="$2"
      ;;
    '--to-ip')
      to_ip="$2"
      ;;
    '--to-port')
      to_port="$2"
      ;;
    '--ssh-key')
      ssh_key="$2"
      ;;
    *)
      ;;
  esac
  if [ $# -gt 0 ]; then
    shift
  else
    break
  fi
done

declare required_args="to_ip to_port ssh_key username jumphost"
declare missing_args="no"
for required_arg in ${required_args[*]}; do
  if [ "${!required_arg}" = "" ]; then
    missing_args="yes"
    echo "You must supply a value for arg --$(sed "s/_/-/g" <<< $required_arg)."
  fi
done
if [ "$missing_args" = "yes" ]; then
  exit 1
fi

# The absolute path to the ssh key for connecting to EC2 instance.
declare ssh_key_val="$(echo "$ssh_key" | base64 -d)"
declare ssh_key_path="$(mktemp -d)/id_rsa"
echo "$ssh_key_val" > "$ssh_key_path"
chmod 600 "$ssh_key_path"

## Deal with zombies or other processes bound to our target port.
## Connect to AWS endpoint and kill any process that may already be bound to the target port.
#ssh -o "StrictHostKeyChecking=no" -i "$ssh_key_path" "$username@$jumphost" "\
#  for process in '$(sudo lsof -i :$from_port | grep 'LISTEN' | sed -E 's/\\s+/ /g' | cut -d' ' -f2)'; do \
#    kill -9 $process; \
#  done;"


# Re-establish the tunnel
autossh -M 0 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
    -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "ExitOnForwardFailure=yes" \
    -nNTv -i "$ssh_key_path" -R "$from_ip:$from_port:$to_ip:$to_port" "$username@$jumphost"

