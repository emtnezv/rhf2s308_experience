# rhf2s308_experiences
Experiences dealing with rhf2s308 for helium mining. 

I am documenting this for my own use (when inevitably I need to flash the firmware and start over).  I would not recommend anyone execute these commands unless you know what you are doing. I will take no responsibility if you mess up your miner. 

# Obtaining shell access

It seems that RisingHF has begun to lock us out of the devices.  The credentials in the manual (https://risinghf-official-website.oss-cn-shenzhen.aliyuncs.com/static/file/product/GX5CI5KeGI7Dl7fFvTrLrA==.pdf) are stated as username/password: `rxhf`/`risinghf`.  These work for a few moments after a firmware flash, but suddenly change moments later. A solution is to quickly create your own username and password, and give yourself sudo access.

1) Flash firmware.  Power cycle.
2) Immediately log in with rxhf/risinghf username/pw combo (via serial (i.e. USB)).
3) `sudo adduser username`
4) `sudo adduser username sudo #give myself sudo access`

(Aside: several moments later, if you try to log in with `rxhf/risinghf` you likely will not be able to.  If you don't want a user account with mystery credentials on *your own hardware*, then you can change the password with `sudo pw rxhf` since you now have your own account with root access).

## Turn on `ssh` access

Run `sudo openssh`. I have found this to be inconsistent.  You might also consider unmasking and enableing the ssh service:

``` bash
systemctl unmask ssh
systemctl enable ssh
systemctl start ssh
```


# Accessing the web dashboard

``` sudo openweb``` will start the web server and give access on port 80 to the dashboard discussed in the manual. The information is generic, and mostly irrelevant to Helium mining.


# Enabling Wifi for Internet

The stock box only uses wifi for diagnostics/debugging/admin.  Thus it creates an access point. If you attempt to connect to Wifi using the Helium app, you might get lucky and do so before this service has created the access point, making it seem like it's working, but the hotspot wifi will not be consistent as the access point services will be constantly battling for access to the wlan0 network interface.  Here I attempt to disable this access point so that I can use the Wifi interface as an internet connection. 

First, we must disable the two services that initialize the access point:
``` bash
systemctl stop init_wifi
systemctl disable init_wifi
systemctl mask init_wifi

systemctl stop create_ap
systemctl disable create_ap
systemctl mask create_ap
```

The networking on this device is managed by `connman`, but if you try to connect to wifi using `connmanctl` right now, you will get a `No Carrier` error. This is because (for some reason) there are two instances of the `wpa_supplicant` service started. 

``` bash 
root@rhf2s308:# ps -aux | grep wpa_supplicant
root       536  0.0  0.1  12564  1704 ?        Ss   14:11   0:00 /sbin/wpa_supplicant -u -s -O /run/wpa_supplicant
root       795  0.0  0.0  12712   836 ?        Ss   14:11   0:00 wpa_supplicant -B -c/etc/wpa_supplicant/wpa_supplicant.conf -iwlan0 -Dnl80211,wext
```

The first one is launched by systemd (you can verify by comparing this command to the `ExecStart` entry in `/usr/lib/systemd/system/wpa_supplicant.service`) and the second is launched by dhcpcd via `/lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant`.  It sounds like this is an issue with Raspberry Pis in general (https://forums.raspberrypi.com/viewtopic.php?t=292401) and it is safe to disable the systemd service, as dhcpcd will take care of launching wpa_supplicant. In fact, if you look at the systemd service status (`systemctl status wpa_supplicant`), you might even see that it's full of complaints that the driver is already in use ("nl80211: kernel reports: Match already configured").  So we stop it and mask it as well:

``` bash 
systemctl stop wpa_supplicant
systemctl disable wpa_supplicant
systemctl mask wpa_supplicant
```

Now, all that's left to do is add our network credentials to the wpa_supplicant configuration file.  Modify `/etc/wpa_supplicant/wpa_supplicant.conf` to look like the following: (the first two lines should already be present; obviously put your own network's credentials. Use `key_mgmt=NONE` for unsecured Wifi (untested)). 
```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
	ssid="MY-WIFI-NETWORK-NAME"
 	psk="My-Password"
}
```
After doing all this and rebooting, I was automatically connected to wifi when the system came back up:

``` bash 
username@rhf2s308:~ $ ifconfig
...
wlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.0.163  netmask 255.255.255.0  broadcast 192.168.0.255
        inet6 fe80::84b9:6e67:6246:417e  prefixlen 64  scopeid 0x20<link>
        ether 20:50:e7:10:9d:4b  txqueuelen 1000  (Ethernet)
        RX packets 2600  bytes 2244628 (2.1 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 2220  bytes 467805 (456.8 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
...

```

My concern was that the Helium miner would have the `eth0` interface hard coded and would not pick up on `wlan0` being connected, but after pulling the ethernet plug, the `peer_book` went relayed as expected (`docker exec miner miner peer book -s`) as I do not have port forwarding set up for the Wifi IP.  Since reboot, I have successfully heard and submitted (over wifi) a witness, so it seems to be working:

```bash
root@rhf2s308:~# docker exec miner cat /var/data/log/console.log | grep --text witness

2022-01-26 15:54:17.375 8 [info] <0.1642.0>@miner_onion_server:decrypt:{372,13} could not decrypt packet received via radio: treating as a witness
2022-01-26 15:54:17.377 8 [info] <0.3142.0>@miner_onion_server:send_witness:{188,13} sending witness at RSSI: -99, Frequency: 904.7, SNR: -2.75
2022-01-26 15:54:17.573 8 [warning] <0.3142.0>@miner_onion_server:send_witness:{243,37} failed to dial challenger "/p2p/redacted": not_found
2022-01-26 15:54:47.592 8 [info] <0.3142.0>@miner_onion_server:send_witness:{246,37} re-sending witness at RSSI: -99, Frequency: 904.7, SNR: -2.75
2022-01-26 15:54:49.193 8 [info] <0.3142.0>@miner_onion_server:send_witness:{251,37} successfully sent witness to challenger "/p2p/redacted" with RSSI: -99, Frequency: 904.7, SNR: -2.75
```

(i.e. it heard a witness, then ~30 seconds later was successful in dialing the challenger)

`HNT: 14LxUtbb6SgpYMxXJESSzKsppPqThoJHh7dFXKZmyCni1N5spKZ`
