#!/bin/bash

[ $(id -u) -eq 0 ] || {
    echo "You must be root"
    exit 1
}

USER=$(stat -c "%U" $(realpath $0))

function set_keyboard() {
  grep -q "us" /etc/default/keyboard && {
    echo "No need to set keyboard ..."
  } || {
    echo "Setting keyboard to US style ..."
    cat <<EOF > /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT=""
XKBOPTIONS="lv3:ralt_alt"

BACKSPACE="guess"
EOF
    echo "Setting keyboard to US style done. Reboot to take effect ..."
  }
}

function set_locale() {
  grep -q "LANG=en_US.UTF-8" /etc/default/locale && {
    echo "No need to set locale ..."
  } || {
    echo "Setting en_US.UTF-8 locale ..."
    cat <<EOF > /etc/default/locale
# File generated by update-locale
LANG=en_US.UTF-8
LC_ALL=C
EOF
    locale-gen en_US.UTF-8
    echo "Setting en_US.UTF-8 locale done."
  }
}

function set_wifi() {
  WPA_USER="BSSID"
  WPA_PASS="WIFIPASS"

  grep -q $WPA_USER /etc/wpa_supplicant/wpa_supplicant.conf && {
    echo "No need to set wifi ..."
  } || {
    wpa_passphrase $WPA_USER $WPA_PASS | sed -e '/#.*$/d' | tee -a /etc/wpa_supplicant/wpa_supplicant.conf > /dev/null
    wpa_cli reconfigure
  }
}

function add_boot_config() {
  grep -q "dtoverlay=i2c-gpio" /boot/config.txt && {
    echo "No need to add boot config ..."
  } || {
    printf "dtoverlay=i2c-gpio,i2c_gpio_sda=10,i2c_gpio_scl=9\ndtparam=i2c_arm=on\n" | tee -a /boot/config.txt
  }
}

function add_module() {
  grep -q "i2c-dev" /etc/modules && {
    echo "No need to add modules ..."
  } || {
    printf "i2c-dev\nrtc-ds1307\n" | tee -a /etc/modules
  }
}

function add_rclocal() {
  grep -q "ds1307" /etc/rc.local && {
    echo "No need to add rclocal ..."
  } || {
    printf "echo ds1307 0x68 > /sys/class/i2c-adapter/i2c-3/new_device\nhwclock --hctosys\n" | tee -a /etc/rc.local
    printf "$(pwd)/PiCollector/scripts/run.sh\n" | tee -a /etc/rc.local
  }
}

set_keyboard
set_locale
set_wifi
add_boot_config
add_module
add_rclocal

echo "Enable ssh ..."
update-rc.d ssh enable

echo "Installing tools ..."
apt-get update
apt-get install -y vim git i2c-tools
node -v &> /dev/null || {
  wget https://raw.githubusercontent.com/audstanley/NodeJs-Raspberry-Pi/master/Install-Node.sh
  sed -i 's/v10\.x/v8\.x/g' Install-Node.sh
  cat Install-Node.sh | bash
  rm Install-Node.sh*
}

[ -d $(pwd)/PiCollector ] || git clone https://github.com/TWSR/PiCollector
chmod a+x $(pwd)/PiCollector/scripts/*.sh
chown -R $USER:$USER $(pwd)/PiCollector
setcap cap_net_raw+epi $(eval readlink -f `which node`)
cd $(pwd)/PiCollector && su $USER -c ./scripts/prepare.sh

