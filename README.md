# DOCUMENTATION ACCESS POINT
____

## I) Pour commencer

### 1) OS
* LEDE 17.01.5

### 2) Packages
* lua (v 5.1.5)
* uci
* uhttpd
* uhttpd-mod-lua  
* coreutils-stat  
* curl  
* arp-scan
* libmysqlclient -- Pour les tests fonctionnels
* luasql-mysql -- Pour les tests fonctionnels

## II) Installation

### 1) Installation locale
* Créer un dossier `wrt` dans `$HOME`.    
* Faire `cd wrt` puis `curl http://downloads.lede-project.org/releases/17.01.5/targets/x86/64/lede-17.01.5-x86-64-generic-rootfs.tar.gz | tar xzf -`.    
* Créer un fichier `resolv.conf` dans `$HOME/wrt/etc/`. Copier le contenu de `/etc/resolv.conf` vers `$HOME/wrt/etc/resolv.conf`.   
* Checkout https://trac.citypassenger.com/projects/browser/solo/access-point/dev-scripts dans le dossier `wrt` pour récupérer les scripts.  
* Faire `sudo chroot . /bin/sh`.    
* Faire `cd /dev-scripts`.    
* Executer le script `init_script.sh`.     

Remarque : Par défaut, uci, lua et uhttpd sont installés. 
Remarque : À chaque redémarrage, lancer le script `./dev-scripts/boot_script` en chroot.  

### 2) Installation en production


## III) Setup
### 1) Fichiers sur openwrt
* Changer le répertoire courant vers celui où est votre image d'openwrt, i.e. dans `wrt`.  
* Checkout depuis https://trac.citypassenger.com/projects/browser/solo/access-point/www dans le dossier `www/`.   
* Checkout depuis https://trac.citypassenger.com/projects/browser/solo/access-point/testing.
Cela devrait nous donner l'arborescence suivante :      
```
/wrt ---/www --- index.lua
     |        |
     |	      |- check.lua
     |	      |  
     |	      |- portal_proxy.lua  
     |	      |
     |	      |- proxy_constants.lua
     |
     |-	/testing --- uhttpd.lua   
     | 		  |  
     |-*  	  |- unit-test.lua  
		  |   
		  |- test-check.lua  
		  |  
		  |- test-scenario.lua  
```
* Dossier `www` :  
`index.lua` : Lua handler.     
`check.lua` : Fonctions d'ajout et vérification sur la base de données locale.    
`portal_proxy.lua` : Fonctions de proxy.  
`proxy_constants.lua` : Constantes provenant du fichier de configuration qui va être téléchargé depuis le réseau.   

* Dossier `testing` :    
`test-index.lua` : Script de test unitaires pour les fonctions dans `check.lua`.    
`uhttpd.lua` : Stub fonction `uhttpd.send`.   
`unit-test.lua` : Fonctions pour les tests unitaires.    
`test-scenario.lua` : Tests fonctionnels.  


### 2) Tests unitaires et tests fonctionnels
* Tests unitaires et fonctionnels en lua :
	* Démarrer le serveur Wordpress.
	* Passer en chroot.
	* Faire `touch /etc/proxy.conf`. Fichier de configuration qui sera une fois en production téléchargé depuis le réseau.
	* Remplir ce fichier avec les lignes suivantes : 
		```
			portal_url=http://portal.citypassenger.com/captive-portal/
			macaddr=/sys/devices/pci0000:00/0000:00:1c.0/0000:02:00.0/net/wlp2s0/address
			localdb=/tmp/ssid-test		
		``` 
	* Pour la ligne `macaddr` remplacer le bon path vers address.  
	* Faire `cd /testing`.    
	* Faire `lua test-index.lua` pour lancer les tests unitaires des fonctions dans `check.lua`.    
	* Faire `lua test-scenario.lua` pour démarrer les test fonctionnels.   

### 3) Usage
* Démarrer le serveur serveur web sur Eclipse si cela n'a pas été fait.
* Démarrer le serveur uhttpd (en étant en chroot) avec le script suivant `script_start_uhttpd 172.16.1.30:9090` qui est dans `/dev-scripts`.
Remarque : Changer l'adresse du serveur web en paramètre du script.  
* Pour on pourra faire `curl http://172.16.1.30:9090/test` pour renvoyer un json avec les informations du client.





