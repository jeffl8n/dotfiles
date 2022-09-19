#!/bin/bash
set -e
set -o pipefail

# install.sh
#	This script installs my basic setup for a debian laptop

export DEBIAN_FRONTEND=noninteractive

# Choose a user account to use for this installation
get_user() {
	if [[ -z "${TARGET_USER-}" ]]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='which user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "Please run as root."
		exit
	fi
}


setup_sources_min() {
	apt update || true
	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release \
		--no-install-recommends

	# turn off translations, speed up apt update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}

# sets up apt sources
# assumes you are going to use debian bullseye
setup_sources() {
	setup_sources_min;

	cat <<-EOF > /etc/apt/sources.list
	deb http://httpredir.debian.org/debian bullseye main contrib non-free
	deb-src http://httpredir.debian.org/debian/ bullseye main contrib non-free

	deb http://httpredir.debian.org/debian/ bullseye-updates main contrib non-free
	deb-src http://httpredir.debian.org/debian/ bullseye-updates main contrib non-free

	deb https://deb.debian.org/debian-security bullseye-security main contrib 
	deb-src https://deb.debian.org/debian-security bullseye-security main contrib

	deb http://httpredir.debian.org/debian experimental main contrib non-free
	deb-src http://httpredir.debian.org/debian experimental main contrib non-free
	EOF

	# tailscale
	curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/tailscale_bullseye.gpg > /dev/null
	curl -fsSL https://pkgs.tailscale.com/stable/debian/bullseye.list | sudo tee /etc/apt/sources.list.d/tailscale.list > /dev/null

	# Add the Cloud SDK distribution URI as a package source
	cat <<-EOF > /etc/apt/sources.list.d/google-cloud-sdk.list
	deb https://packages.cloud.google.com/apt cloud-sdk main
	EOF

	# Import the Google Cloud Platform public key
	curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/google_cloud_platform.gpg > /dev/null

	# Add the Google Chrome distribution URI as a package source
	cat <<-EOF > /etc/apt/sources.list.d/google-chrome.list
	deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main
	EOF

	# Import the Google Chrome public key
	curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/google_chrome.gpg > /dev/null

	# Add the Brave browser package source
	cat <<-EOF > /etc/apt/sources.list.d/brave-browser-release.list
	deb [arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main
	EOF

	# Import the Brave browser public key
	curl -fsSL https://brave-browser-apt-release.s3.brave.com/brave-core.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/brave.gpg > /dev/null

	# Add the Virtualbox package source
	cat <<-EOF > /etc/apt/sources.list.d/virtualbox-release.list
	deb [arch=amd64] https://download.virtualbox.org/virtualbox/debian bullseye contrib
	EOF

	# Import the Virtualbox public key
	curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/virtualbox.gpg > /dev/null

	# Add the Microsoft package source
	cat <<-EOF > /etc/apt/sources.list.d/microsoft-release.list
	deb [arch=amd64] https://packages.microsoft.com/debian/11/prod bullseye main
	EOF

	# Import the Microsoft public key
	curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft-release.gpg > /dev/null

	# Add the llvm package source
	cat <<-EOF > /etc/apt/sources.list.d/llvm-release.list
	deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye main
	deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye main
	# 14 
	deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-14 main
	deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-14 main
	# 15 
	deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-15 main
	deb-src http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-15 main
	EOF

	# Import the llvm public key
	curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/llvm.gpg > /dev/null
}

base_min() {
	apt update || true
	apt -y upgrade

	apt install -y \
		adduser \
		automake \
		bash-completion \
		bc \
		bzip2 \
		ca-certificates \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		gcc \
		git \
		gnupg \
		gnupg2 \
		grep \
		gzip \
		hostname \
		indent \
		iptables \
		jq \
		less \
		libc6-dev \
		locales \
		lsof \
		make \
		mount \
		net-tools \
		ngrep \
		policykit-1 \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		tar \
		tcpdump \
		tree \
		tzdata \
		unzip \
		xz-utils \
		zip \
		--no-install-recommends

	apt autoremove -y
	apt autoclean -y
	apt clean -y

	install_scripts
}

# installs base packages
# the utter bare minimal shit
base() {
	base_min;

	apt update || true
	apt -y upgrade

	apt install -y \
		apparmor \
		bridge-utils \
		cgroupfs-mount \
		fwupd \
		fwupdate \
		gnupg-agent \
		google-cloud-sdk \
		iwd \
		libapparmor-dev \
		libimobiledevice6 \
		libltdl-dev \
		libpam-systemd \
		libpcsclite-dev \
		libseccomp-dev \
		mutt \
		pcscd \
		pinentry-curses \
		scdaemon \
		systemd \
		tailscale \
		openvpn \
		virtualbox-6.1 \
		dotnet-sdk-6.0 \
		--no-install-recommends

	setup_sudo

	apt autoremove -y
	apt autoclean -y
	apt clean -y
}

# install and configure dropbear
install_dropbear() {
	apt update || true
	apt -y upgrade

	apt install -y \
		dropbear-initramfs \
		--no-install-recommends

	apt autoremove -y
	apt autoclean -y
	apt clean -y

	# change the default port and settings
	echo 'DROPBEAR_OPTIONS="-p 4748 -s -j -k -I 60"' >> /etc/dropbear-initramfs/config

	# update the authorized keys
	cp "/home/${TARGET_USER}/.ssh/authorized_keys" /etc/dropbear-initramfs/authorized_keys
	sed -i 's/ssh-/no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="\/bin\/cryptroot-unlock" ssh-/g' /etc/dropbear-initramfs/authorized_keys

	echo
	echo "Updated config in /etc/dropbear-initramfs/config:"
	cat /etc/dropbear-initramfs/config
	echo

	echo "Updated authorized_keys in /etc/dropbear-initramfs/authorized_keys:"
	cat /etc/dropbear-initramfs/authorized_keys
	echo

	echo "Dropbear has been installed and configured."
	echo
	echo "You will now want to update your initramfs:"
	printf "\\tupdate-initramfs -u\\n"
}

# setup sudo for a user
# because fuck typing that shit all the time
# just have a decent password
# and lock your computer when you aren't using it
# if they have your password they can sudo anyways
# so its pointless
# i know what the fuck im doing ;)
setup_sudo() {
	# add user to sudoers
	adduser "$TARGET_USER" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	# create docker group
	sudo groupadd -f docker
	sudo gpasswd -a "$TARGET_USER" docker

	# add go path to secure path if it doesn't already exist
	LINE="Defaults	secure_path=\"/usr/local/go/bin:/home/${TARGET_USER}/.go/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/${TARGET_USER}/.cargo/bin\""
	FILE="/etc/sudoers"
	grep -qPx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
	LINE="Defaults	env_keep += \"ftp_proxy http_proxy https_proxy no_proxy GOPATH EDITOR\""
	grep -qx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
	LINE="${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"
	grep -qx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
	LINE="${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"
	grep -qPx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

	# setup downloads folder as tmpfs
	# that way things are removed on reboot
	# i like things clean but you may not want this
	mkdir -p "/home/$TARGET_USER/Downloads"
	LINE='# tmpfs for downloads'
	FILE="/etc/fstab"
	grep -qPx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
	LINE="tmpfs\\t/home/${TARGET_USER}/Downloads\\ttmpfs\\tnodev,nosuid,size=5G\\t0\\t0"
	grep -qPx -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}

# install rust

install_rust() {
	curl https://sh.rustup.rs -sSf | sh

	# Install rust-src for rust analyzer
	rustup component add rust-src
	# Install rust-analyzer
	curl -sfSL "https://github.com/rust-analyzer/rust-analyzer/releases/download/2020-04-20/rust-analyzer-linux" -o "${HOME}/.cargo/bin/rust-analyzer"
	chmod +x "${HOME}/.cargo/bin/rust-analyzer"

	# Install clippy
	rustup component add clippy
}

# install/update golang from source
install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -fSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	if [[ -z ${GOPATH} ]]; then
		export GOPATH="${HOME}/.go"
		export PATH="/usr/local/go/bin:${GOPATH}/bin:${PATH}"
	fi

	# if we are passing the version
	if [[ -n "$1" ]]; then
		GO_VERSION=$1
	fi

	# purge old src
	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi
	sudo mkdir "$GO_SRC"
	mkdir "$GOPATH"

	GO_VERSION=${GO_VERSION#go}

	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sfSL "https://storage.googleapis.com/golang/go${GO_VERSION}.${kernel}-amd64.tar.gz" | sudo tar -v -C /usr/local -xz
	local user="$USER"
	# rebuild stdlib for faster builds
	sudo chown -R "${user}" "${GO_SRC}/pkg"
	sudo chown -R "${user}" "$GOPATH"
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)

	# get commandline tools
	(
	set -x
	set +e
	go get golang.org/x/lint/golint
	go get golang.org/x/tools/cmd/cover
	go get golang.org/x/tools/gopls
	go get golang.org/x/review/git-codereview
	go get golang.org/x/tools/cmd/goimports
	go get golang.org/x/tools/cmd/gorename
	go get golang.org/x/tools/cmd/guru

	go get github.com/genuinetools/amicontained
	go get github.com/genuinetools/apk-file
	go get github.com/genuinetools/audit
	go get github.com/genuinetools/bpfd
	go get github.com/genuinetools/bpfps
	go get github.com/genuinetools/certok
	go get github.com/genuinetools/netns
	go get github.com/genuinetools/pepper
	go get github.com/genuinetools/reg
	go get github.com/genuinetools/udict
	go get github.com/genuinetools/weather

	go get github.com/jessfraz/junk/sembump
	go get github.com/jessfraz/secping
	go get github.com/jessfraz/tdash

	go get github.com/axw/gocov/gocov
	go get honnef.co/go/tools/cmd/staticcheck
	go get github.com/muesli/duf
	go get github.com/google/gops

	# Hugo (for blog)
	go get github.com/gohugoio/hugo

	# Tools for vimgo.
	go get github.com/jstemmer/gotags
	go get github.com/nsf/gocode
	go get github.com/rogpeppe/godef

	aliases=( ) # ( genuinetools/contained.af genuinetools/binctr genuinetools/img docker/docker moby/buildkit opencontainers/runc )
	for project in "${aliases[@]}"; do
		owner=$(dirname "$project")
		repo=$(basename "$project")
		if [[ -d "${HOME}/${repo}" ]]; then
			rm -rf "${HOME:?}/${repo}"
		fi

		mkdir -p "${GOPATH}/src/github.com/${owner}"

		if [[ ! -d "${GOPATH}/src/github.com/${project}" ]]; then
			(
			# clone the repo
			cd "${GOPATH}/src/github.com/${owner}"
			git clone "https://github.com/${project}.git"
			# fix the remote path, since our gitconfig will make it git@
			cd "${GOPATH}/src/github.com/${project}"
			git remote set-url origin "https://github.com/${project}.git"
			)
		else
			echo "found ${project} already in gopath"
		fi

		# make sure we create the right git remotes
		if [[ "$owner" != "jeffl8n" ]]; then
			(
			cd "${GOPATH}/src/github.com/${project}"
			git remote set-url --push origin no_push
			git remote add jeffl8n "https://github.com/jeffl8n/${repo}.git"
			)
		fi
	done

	# do special things for k8s GOPATH
	# mkdir -p "${GOPATH}/src/k8s.io"
	# kubes_repos=( community kubernetes release sig-release )
	#for krepo in "${kubes_repos[@]}"; do
	#	git clone "https://github.com/kubernetes/${krepo}.git" "${GOPATH}/src/k8s.io/${krepo}"
	#	cd "${GOPATH}/src/k8s.io/${krepo}"
	#	git remote set-url --push origin no_push
	#	git remote add jeffl8n "https://github.com/jeffl8n/${krepo}.git"
	#done
	)

	# symlink weather binary for motd
	sudo ln -snf "${GOPATH}/bin/weather" /usr/local/bin/weather
}

# install graphics drivers
install_graphics() {
	local system=$1

	if [[ -z "$system" ]]; then
		echo "You need to specify whether it's intel, amd, geforce, or optimus"
		exit 1
	fi

	local pkgs=( xorg xserver-xorg xserver-xorg-input-libinput xserver-xorg-input-synaptics )

	case $system in
		"intel")
			pkgs+=( xserver-xorg-video-intel )
			;;
		"geforce")
			pkgs+=( nvidia-driver )
			;;
		"optimus")
			pkgs+=( nvidia-kernel-dkms bumblebee-nvidia primus )
			;;
		"amd")
			pkgs+=( mesa xserver-xorg-video-amdgpu firmware-linux-nonfree libgl1-mesa-dri )
			;;
		*)
			echo "You need to specify whether it's intel, amd, geforce, or optimus"
			exit 1
			;;
	esac

	apt update || true
	apt -y upgrade

	apt install -y "${pkgs[@]}" --no-install-recommends
}

# install custom scripts/binaries
install_scripts() {
	# install speedtest
	curl -sfSL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py > /usr/local/bin/speedtest
	chmod +x /usr/local/bin/speedtest

	# install icdiff
	curl -sfSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/icdiff > /usr/local/bin/icdiff
	curl -sfSL https://raw.githubusercontent.com/jeffkaufman/icdiff/master/git-icdiff > /usr/local/bin/git-icdiff
	chmod +x /usr/local/bin/icdiff
	chmod +x /usr/local/bin/git-icdiff

	# install lolcat
	curl -sfSL https://raw.githubusercontent.com/tehmaze/lolcat/master/lolcat > /usr/local/bin/lolcat
	chmod +x /usr/local/bin/lolcat
}

# install stuff for i3 window manager
install_wmapps() {
	sudo apt update || true
	sudo apt install -y \
		bluez \
		bluez-firmware \
		brave-browser \
		feh \
		google-chrome-stable \
		i3 \
		i3lock \
		i3status \
		pulseaudio \
		pulseaudio-module-bluetooth \
		pulsemixer \
		rofi \
		rxvt-unicode-256color \
		scrot \
		usbmuxd \
		xclip \
		xcompmgr \
		--no-install-recommends

	# start and enable pulseaudio
	systemctl --user daemon-reload
	systemctl --user enable pulseaudio.service
	systemctl --user enable pulseaudio.socket
	systemctl --user start pulseaudio.service

	echo "Fonts file setup successfully now run:"
	echo "	dpkg-reconfigure fontconfig-config"
	echo "with settings: "
	echo "	Autohinter, Automatic, No."
	echo "Run: "
	echo "	dpkg-reconfigure fontconfig"
}

get_dotfiles() {
	# create subshell
	(
	cd "$HOME"

	if [[ ! -d "${HOME}/dotfiles" ]]; then
		# install dotfiles from repo
		git clone git@github.com:jeffl8n/dotfiles.git "${HOME}/dotfiles"
	fi

	cd "${HOME}/dotfiles"

	# set the correct origin
	git remote set-url origin git@github.com:jeffl8n/dotfiles.git

	# installs all the things
	make

	# enable dbus for the user session
	# systemctl --user enable dbus.socket

	sudo systemctl enable "i3lock@${TARGET_USER}"

	cd "$HOME"
	mkdir -p ~/Pictures/Screenshots
	)

	install_vim;
}

install_nodejs() {
	curl -sfSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/nodesource.gpg > /dev/null

	# FROM: https://github.com/nodesource/distributions/blob/master/README.md
	# Replace with the branch of Node.js or io.js you want to install: node_6.x,
	# node_8.x, etc...
	VERSION=node_16.x
	# The below command will set this correctly, but if lsb_release isn't available, you can set it manually:
	# - For Debian distributions: jessie, sid, etc...
	# - For Ubuntu distributions: xenial, bionic, etc...
	# - For Debian or Ubuntu derived distributions your best option is to use
	# the codename corresponding to the upstream release your distribution is
	# based off. This is an advanced scenario and unsupported if your
	# distribution is not listed as supported per earlier in this README.
	DISTRO="$(lsb_release -s -c)"
	echo "deb https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list
	echo "deb-src https://deb.nodesource.com/$VERSION $DISTRO main" | sudo tee -a /etc/apt/sources.list.d/nodesource.list

	sudo apt update || true
	sudo apt install -y \
		nodejs \
		--no-install-recommends
}

install_vim() {
	# Install node, needed for coc.vim
	install_nodejs

	sudo apt update || true
	sudo apt install -y \
		vim-nox \
		python3-dev \
		mono-complete \
		--no-install-recommends

	# create subshell
	(
	cd "$HOME"

	# install .vim files
	sudo rm -rf "${HOME}/.vim"
	git clone --recursive git@github.com:jeffl8n/.vim.git "${HOME}/.vim"
	(
	cd "${HOME}/.vim"
	make install
	)

	# update alternatives to vim
	sudo update-alternatives --install /usr/bin/vi vi "$(command -v vim)" 60
	sudo update-alternatives --config vi
	sudo update-alternatives --install /usr/bin/editor editor "$(command -v vim)" 60
	sudo update-alternatives --config editor
	)
}

install_tools() {
	echo "Installing golang..."
	echo
	install_golang;

	echo
	echo "Installing rust..."
	echo
	install_rust;

	echo
	echo "Installing scripts..."
	echo
	sudo install.sh scripts;
}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  base                                	- setup sources & install base pkgs"
	echo "  basemin                             	- setup sources & install base min pkgs"
	echo "  graphics {intel, amd, geforce, optimus}  - install graphics drivers"
	echo "  wm                                  	- install window manager/desktop pkgs"
	echo "  dotfiles                            	- get dotfiles"
	echo "  vim                                 	- install vim specific dotfiles"
	echo "  nodejs                              	- install nodejs"
	echo "  golang                              	- install golang and packages"
	echo "  rust                                	- install rust"
	echo "  scripts                             	- install scripts"
	echo "  tools                               	- install golang, rust, and scripts"
	echo "  dropbear                            	- install and configure dropbear initramfs"
}

main() {
	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "base" ]]; then
		check_is_sudo
		get_user

		# setup /etc/apt/sources.list
		setup_sources

		base
	elif [[ $cmd == "basemin" ]]; then
		check_is_sudo
		get_user

		# setup /etc/apt/sources.list
		setup_sources_min

		base_min
	elif [[ $cmd == "graphics" ]]; then
		check_is_sudo

		install_graphics "$2"
	elif [[ $cmd == "wm" ]]; then
		install_wmapps
	elif [[ $cmd == "dotfiles" ]]; then
		get_user
		get_dotfiles
	elif [[ $cmd == "vim" ]]; then
		install_vim
	elif [[ $cmd == "nodejs" ]]; then
		install_nodejs
	elif [[ $cmd == "rust" ]]; then
		install_rust
	elif [[ $cmd == "golang" ]]; then
		install_golang "$2"
	elif [[ $cmd == "scripts" ]]; then
		install_scripts
	elif [[ $cmd == "tools" ]]; then
		install_tools
	elif [[ $cmd == "dropbear" ]]; then
		check_is_sudo

		get_user

		install_dropbear
	else
		usage
	fi
}

main "$@"
