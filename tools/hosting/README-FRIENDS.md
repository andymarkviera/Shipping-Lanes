# Container Ship Sim — friends playtest

Extract the whole folder, then double-click Launch-Client.cmd. Choose Servers,
select your host, and Sign In & Join. Sign-in opens in your browser. Use the
individual account your host gives you; automatic signup/Google login is not enabled.
Settings adjusts your controls/audio. Quit closes the game.

Keep Game, internet.json and server-certificate.pem together. The launcher uses
an isolated PlayerData folder for your settings and a process-only PowerShell
execution-policy allowance to run the included launcher. You can inspect both
launcher files first. Opening Game/ShippingLanes.exe directly also works and reads
the same server connection files, but uses the ordinary local settings directory.
Never redistribute PlayerData. No Godot editor is needed.

If the server list says connection files are missing, this is the unconfigured
template: your host must complete the section below before distributing it.
If browser sign-in reports a certificate trust error, ask your host to finish the
certificate setup; do not bypass warnings or disable certificate checking.

## Host: prepare this client with your existing server

This client uses the same game protocol 13 and ticket protocol 7 as the Windows
hosting preview. It does not need a server database reset or server runtime update.
It changes menu presentation and portable configuration loading only.

Copy this entire friends template folder onto the server PC. Start the existing
dedicated server and wait for HOST_READY. Its generated Client folder contains
the public configuration/certificate for that specific server. From this template:

```powershell
.\Configure-Friends-Client.ps1 -HostClientFolder C:\ShippingLanesHost\Client
```

Adjust the path if the host was extracted elsewhere. This produces
ShippingLanes-Friends-Ready.zip beside the template, using only approved public
files and the game. Share that ZIP, not the initialized host folder. The script
does not modify the host, identities, passwords, certificates or saves.

Before friends connect from the internet, the server PC still needs a stable
reachable hostname, working HTTPS certificate trust, and the configured TCP 8443
and UDP 24560 connectivity. DuckDNS alone is not a tunnel or port-forwarding rule.
Use the host's CHATGPT-SERVER-HANDOFF.md for setup. A LAN IP such as SERVER_LAN_IP
cannot be reached directly by friends outside your home. Test from another network.
The existing preview creates only two test accounts; each player needs a distinct
enrolled account. General-public signup, Google login, production identity storage
and certificate renewal remain unfinished. Invited testing via a private VPN or
restricted network access is the current deployment scope.

For home use, copy lan.json from the host Client folder alongside internet.json
and run Launch-Client.ps1 -Connection LAN. Sign-in still uses the stable hostname;
your home DNS/router must resolve/reach it correctly. The ready ZIP intentionally
ships only the Internet route. Both routes use the same online account/save.
