# [Lynx][1] Cryptocurrency Installer (LynxCI)

Creates a Lynx cryptocurrency node that confirms and relays transactions, provides wallet functions and runs an eco-friendly, built-in solo miner.

## [LynxCI for Pi 4][3]

If you want to get your Raspberry Pi up and running quick, the following ISO is for you. Simply [download the LynxCI ISO from here][4] and then flash it to an SD card. [The Raspberry Pi Imager][5] is great for flashing your SD card quick. Plugin in the ethernet cable, then insert the card into the SD card slot on the bottom of the Raspberry Pi and power it on. No keyboard, mouse or monitor is required. It will be fully functional in about 20 minutes.

\>>> [Click here to get the latest ISO file for your Raspberry Pi Imager][3] <<<

For complete details on the above ISO, please visit this [Medium article][9] for all the information you need.

## One line install script

**THIS SCRIPT IS ONLY FOR dedicated computers, VPS or Raspberry Pi. If you have data or user accounts on your computer, DO NOT USE THIS SCRIPT. It is only to be used after a freshly installed operating system.**

This script supports the following Linux operating systems. [Raspberry Pi OS][2], Debian 11 (Bullseye), Debian 10 (Buster), Ubuntu 20.10 & Ubuntu 20.04 LTS. The script is only recommended for a VPS or local server that has a freshly installed OS with no previously written data. Seriously, don't execute this script on a VPS that has data you care about. This precaution is for your own security.

You can execute the following install script, as 'root', after your OS is installed and updated. Just copy/paste and hit return. 

	wget -qO - https://getlynx.io/install.sh | bash

For complete details on the above command, please visit this [Medium article][9] for all the information you need.

## Help

Helpful articles about Lynx and LynxCI are available on our [Medium channel][7]. Join our active [Discord][8] community for questions and mining incentives.

## Bootstrap File

A (relatively) current bootstrap file can be downloaded [here][14]. Any remaining blocks will be synced automatically. The bootstrap is used automatically in the LynxCI install.

[1]:	https://getlynx.io
[2]:	https://www.raspberrypi.org/software/operating-systems/
[3]:	https://github.com/getlynx/LynxCI/releases/download/v27-ISO/2021-01-11-LynxCI.tar.gz
[4]:	https://github.com/getlynx/LynxCI/releases/tag/v27-ISO
[5]:	https://www.raspberrypi.org/software/
[7]:	https://medium.com/lynx-blockchain
[8]:	https://discord.getlynx.io/
[9]:	https://medium.com/lynx-blockchain/intermediate-using-the-lynx-cryptocurrency-installer-lynxci-363b00784a34
[14]:	https://github.com/getlynx/LynxBootstrap/releases
