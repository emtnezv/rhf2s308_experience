# rhf2s308_experience
Experiences dealing with rhf2s308 for helium mining


# Connecting to Wifi
The stock box only uses wifi for diagnostics/debugging/admin.  Thus it creates an access point. If you attempt to connect to Wifi using the Helium app, you might get lucky and do so before this service has created the access point, making it seem like it's working, but the hotspot wifi will not be consistent as the access point services will be constantly battling for access to the network interface.  Here I attempt to disable this access point so that I can use the Wifi interface as a network connection. 

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

The first one is launched by systemd (you can verify by comparing this command to the `ExecStart` entry in `/usr/lib/systemd/system/wpa_supplicant.service`) and the second is launched by dhcpcd via `/lib/dhcpcd/dhcpcd-hooks/10-wpa_supplicant`.  It sounds like this is an issue with Raspberry Pis (https://forums.raspberrypi.com/viewtopic.php?t=292401) and it is safe to disable the systemd service, as dhcpcd will take care of launching wpa_supplicant. In fact, if you look at the systemd service status (`systemctl status wpa_supplicant`), you might even see that it's full of complaints that the driver is already in use ("nl80211: kernel reports: Match already configured").  So we stop, disable, and mask it as well.

``` bash 
systemctl stop wpa_supplicant
systemctl disable wpa_supplicant
systemctl mask wpa_supplicant
```

Now, all that's left to do is add our network credentials to the wpa_supplicant configuration file.  modify `/etc/wpa_supplicant/wpa_supplicant.conf` to look like the following: (the first two lines should already be present). 
```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
	ssid="MY-WIFI-NETWORK-NAME"
 	psk="My-Password"
}
```


