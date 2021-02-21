# Usage

## create-autossh-tunnel.sh
```bash
./create-autossh-tunnel.sh --to-port 80 --to-ip 10.10.2.20 --ssh-key "$(cat ~/.ssh/id_rsa | base64 -w0)" --username ubuntu --jumphost 45.45.87.42
```
