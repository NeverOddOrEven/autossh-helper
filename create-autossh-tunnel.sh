#!/bin/bash

declare from_ip="${FROM_IP:-0.0.0.0}"
declare from_port="${FROM_PORT:-9999}"
declare to_ip="${TO_IP}"
declare to_port="${TO_PORT}"
declare b64_ssh_key="${B64_SSH_KEY}"
declare username="${USERNAME}"
declare jumphost="${JUMPHOST}"

function usage() {
  echo "$0 [required parameters] [optional parameters]"
  echo 
  echo "  create a tunnel on the jumphost that exposes the target ip (--to-ip) and target port (--to-port)"
  echo "  by default, you may access the target via the jumphost on interface 0.0.0.0 (--from-ip) and port 9999 (--from-port)"
  echo
  echo "required parameters (may also be set via the environment as noted in the square braces)"
  echo
  echo "  --jumphost [JUMPHOST]                     the ip address or hostname of the remote server"
  echo "  --username [USERNAME]                     the username for the user to connect to the jumphost"
  echo "  --b64-ssh-key [B64_SSH_KEY]               the ssh key for the specified user"
  echo "  --to-ip [TO_IP]                           the ip address of the proxy target"
  echo "  --to-port [TO_PORT]                       the port of the proxy target "
  echo
  echo "optional parameters"
  echo "  --from-ip [FROM_IP]     (default: 0.0.0.0)  the ip address of the listening interface on the jumphost"
  echo "  --from-port [FROM_PORT] (default: 9999)     the port on the listening interface on the jumphost"
  echo 
  echo "example"
  echo "  # this will connect to the jumphost and create an ssh tunnel to the target 10.10.76.10:443"
  echo "  $0 --jumphost myvm.somecloud.net --username alex --b64-ssh-key \"\$(cat ~/.ssh/id_rsa | base64 -w0)\" --to-ip 10.10.76.10 --to-port 443" 
  echo ""
}

# We need TEMP as the 'eval set --' would nuke the return value of getopt.
TEMP="$(getopt -o 'h' --long 'jumphost:,username:,from-port:,from-ip:,to-port:,to-ip:,b64-ssh-key:,help' -- "$@")"

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
    '--b64-ssh-key')
      b64_ssh_key="$2"
      ;;
    '-h'|'--help')
      usage
      exit 0
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

declare required_args="to_ip to_port b64_ssh_key username jumphost"
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
declare ssh_key_val="$(echo "$b64_ssh_key" | base64 -d)"
declare ssh_key_path="$(mktemp -d)/id_rsa"
echo "$ssh_key_val" > "$ssh_key_path"
chmod 600 "$ssh_key_path"

## Might try to re-enable this later, but it's complicated by the need to use sudo
## Deal with zombies or other processes bound to our target port.
## Connect to AWS endpoint and kill any process that may already be bound to the target port.
#ssh -o "StrictHostKeyChecking=no" -i "$ssh_key_path" "$username@$jumphost" "\
#  for process in '$(sudo lsof -i :$from_port | grep 'LISTEN' | sed -E 's/\\s+/ /g' | cut -d' ' -f2)'; do \
#    kill -9 $process; \
#  done;"

echo "***********************************************"
echo "To create a tunnel from your localhost to the jumphost, run:"
echo "***********************************************"
echo 
echo "ssh-o \"ServerAliveInterval=30\" -o \"ServerAliveCountMax=3\" -o \"StrictHostKeyChecking=no\" -o \"ConnectTimeout=5\" -o \"ExitOnForwardFailure=yes\" \\"
echo "  -nNTv -i \"$ssh_key_path\" -L \"0.0.0.0:9999:127.0.0.1:$from_port\" \"$username@$jumphost\""
echo 
echo "***********************************************"
echo "Creating tunnel from the jumphost to the target" 
echo "***********************************************"
echo 

# Re-establish the tunnel
autossh -M 0 -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" \
    -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "ExitOnForwardFailure=yes" \
    -nNTv -i "$ssh_key_path" -R "$from_ip:$from_port:$to_ip:$to_port" "$username@$jumphost"

