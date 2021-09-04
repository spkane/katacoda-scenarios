#!/usr/bin/env bash

set -eu

date '+%Y%m%d-%H%M%S' > /etc/build_timestamp

DOCKER_COMPOSE_V1_VERSION="1.29.2"
DOCKER_COMPOSE_v2_VERSION="v2.0.0-rc.1"
GITHUB_CLI_VERSION="2.0.0"
GO_VERSION="1.16.7"
KIND_VERSION="v0.11.1"
YQ_VERSION="4.12.1"

cd /tmp

touch ~/.bashrc

# Fix an underlying bug in Katacoda's Unbuntu:2004 image
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -

# Remove suspect SSH private key
rm -f ~/.ssh/id_rsa
rm -f ~/.ssh/authorized_keys

apt-get update  
apt-get -y upgrade 

apt-get  install -y \
    bash-completion \
    fonts-firacode

# grub
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cgroup_enable=memory swapaccount=1"/' /etc/default/grub
update-grub

# bashrc
echo '' >> ~/.bashrc

cat << "EOF" >> ~/.bashrc
set -o vi

shopt -s checkwinsize
shopt -s histappend

export HISTSIZE=5000
export HISTFILESIZE=5000
export HISTCONTROL=ignoreboth:erasedups
export HISTTIMEFORMAT="%d/%m/%y %T "
export HISTIGNORE="ls:pwd:clear:reset:[bf]g:exit"
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export CLICOLOR=1
export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx
export GREP_COLOR='1;30;43'
export TERM=xterm

alias vi="vim -y"
alias vim="vim -y"
EOF

# Install Starship Prompt
wget -O /tmp/starship.sh https://starship.rs/install.sh
bash /tmp/starship.sh --force
rm -f /tmp/starship.sh
echo 'eval "$(starship init bash)"' >> ~/.bashrc
mkdir ~/.config

cat << "EOF" > ~/.config/starship.toml
# Don't print a new line at the start of the prompt
add_newline = false

# use custom prompt order
format = """\
    $env_var\
    $username\
    $hostname\
    $directory\
    $kubernetes\
    $aws\
    $git_branch\
    $git_commit\
    $git_state\
    $git_status\
    $hg_branch\
    $package\
    $dotnet\
    $golang\
    $java\
    $nodejs\
    $python\
    $ruby\
    $rust\
    $terraform\
    $nix_shell\
    $conda\
    $memory_usage\
    $cmd_duration\
    $line_break\
    $jobs\
    $battery\
    $time\
    $character\
    """

# Wait 30 milliseconds for starship to check files under the current directory.
scan_timeout = 30

[aws]
format = '[$symbol $profile($region)]($style) '
style = '#668cff'
symbol = '🅰'

[aws.region_aliases]
us-east-1 = 'use1'
us-east-2 = 'use2'
us-west-1 = 'usw1'
us-west-2 = 'usw2'

[directory]
truncation_length = 3

[golang]
format = '[$symbol$version]($style)'

[hostname]
ssh_only = true
format = '⟪[$hostname]($style)⟫'
trim_at = '.'
disabled = false

[kubernetes]
format = '[$symbol$context\($namespace\)]($style) '
symbol = '⛵'
style = 'green'
disabled = false

[python]
format = '[${symbol}${pyenv_prefix}${version}($virtualenv)]($style) '
style = 'yellow'

[ruby]
format = '[$symbol$version]($style) '

[username]
disabled = true
EOF

# Update Go
rm -rf /usr/local/go
wget "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz"
tar -xvf go${GO_VERSION}.linux-amd64.tar.gz
mv go /usr/local

# Install Github CLI
wget "https://github.com/cli/cli/releases/download/v${GITHUB_CLI_VERSION}/gh_${GITHUB_CLI_VERSION}_linux_amd64.deb"
DEBIAN_FRONTEND=noninteractive dpkg -i gh_${GITHUB_CLI_VERSION}_linux_amd64.deb

# Install yq
wget "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64"
install -o root -g root -m 0755 yq_linux_amd64 /usr/local/bin/yq

# Install the official Docker release
apt-get remove -y docker docker-engine docker.io containerd runc
apt-get autoremove -y
apt-get update -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Change the storage driver to overlay2
sed -i s/"overlay"/"overlay2"/ /etc/docker/daemon.json
systemctl restart docker

# Setup docker buildx multiarch builder
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --name builder --driver docker-container --use
docker buildx inspect --bootstrap

# Install Docker Compose v1
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_V1_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
curl \
    -L https://raw.githubusercontent.com/docker/compose/${DOCKER_COMPOSE_V1_VERSION}/contrib/completion/bash/docker-compose \
    -o /etc/bash_completion.d/docker-compose

# Install Docker Compose v2
 mkdir -p ~/.docker/cli-plugins/
 curl -SL https://github.com/docker/compose-cli/releases/download/${DOCKER_COMPOSE_v2_VERSION}/docker-compose-linux-amd64 -o ~/.docker/cli-plugins/docker-compose
 chmod +x ~/.docker/cli-plugins/docker-compose
 
# Install Terraform
apt-get update -y && apt-get install -y gnupg software-properties-common curl
curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
apt-get update -y && apt-get install -y terraform
terraform -install-autocomplete

# Install kubectl
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl
curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64
chmod +x ./kind
install -o root -g root -m 0755 kind /usr/local/bin/kind
rm -f ./kind

exit 0
