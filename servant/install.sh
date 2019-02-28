#!/usr/bin/env bash
CONTROLLER='https://cauchy.aosc.io/jnlpJars/agent.jar'

# detections
if [[ "x$(id --user)" != 'x0' ]]; then
  echo 'Please run this script as root.'
  exit 1
fi

if ! java -version; then
  echo 'JRE is required to run this service'
  echo 'Install Java Runtime Environment or JDK'
  exit 1
fi

function display_params() {
  if [ -z "${TOKEN}" ]; then
    TOKEN_DISPLAY='<None>'
  else
    TOKEN_DISPLAY="${TOKEN:0:5}*****"
  fi
  cat << EOC

The following configurations are detected:
-- Connection endpoint: ${JNLP_URL}
-- Working directory: ${WORKDIR}
-- Token: ${TOKEN_DISPLAY}
EOC
}

function collect_params() {
  echo -e '\n\n\n'
  read -p '[?] JNLP URL: ' JNLP_URL
  read -p '[?] Working directory: ' WORKDIR
  read -p '[?] Secret: ' -s TOKEN
}

# user inputs
function collect_config() {
  echo '[?] Copy and paste what Jenkins wants you to run to launch the agent (begins with `java -jar`)'
  echo '[?] Hit enter directly to input parameters manually'
  read -a CMD
  if [ -z "${CMD[0]}" ]; then
    collect_params
  else
    JNLP_URL="${CMD[4]}"
    TOKEN="${CMD[6]}"
    WORKDIR="${CMD[8]}"
  fi

  display_params
  read -p '[?] Is it correct? [Y/N] ' -N1 CORRECT

  if [[ "x${CORRECT}" != 'xY' ]]; then
    echo -e "\n[!] Let's try again"
    collect_config
  fi
}

collect_config

# actions
TMPDIR="$(mktemp -d)"

echo '[+] Download and install Jenkins controller...'
wget -q --show-progress "${CONTROLLER}" -O "${TMPDIR}/agent.jar"
mkdir -p '/usr/share/jenkins-servant/'
cp -v "${TMPDIR}/agent.jar" '/usr/share/jenkins-servant/'

echo '[+] Setting up an exclusive account for servant...'
useradd -m -s /bin/bash servant
echo 'servant ALL=(ALL) NOPASSWD: ALL' > '/etc/sudoers.d/10-aosc-alice'

cat << EOF > '/usr/share/jenkins-servant/config'
JNLP_URL=${JNLP_URL}
TOKEN=${TOKEN}
WORKDIR=${WORKDIR}
EOF

echo '[+] Setting up permission for work dir...'
chown -hR servant:servant "${WORKDIR}"

echo '[+] Copying systemd unit file...'
MY_LOCATION="$(dirname $0)"
cp -v "$(readlink -f ${MY_LOCATION})/./aosc-alice-servant.service" '/usr/lib/systemd/system/'
systemctl daemon-reload

rm -rf "${TMPDIR}"
