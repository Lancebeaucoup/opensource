# Script de configuration post-installation pour les serveurs CentOS 7 

(c) Niki Kovacs, 2020
Ce référentiel fournit un script de configuration post-installation "automagique" pour
serveurs exécutant CentOS 7 ainsi qu'une collection de scripts d'assistance et
modèles de fichiers de configuration pour les services communs.

## En nutshell

Effectuez les étapes suivantes.

1. Installez un système CentOS 7 minimal.

2. Créez un utilisateur non "root" avec des privilèges d'administrateur.

3. Installez Git: `sudo yum install git`

4. Saisissez le script: `git clone https://gitlab.com/kikinovak/centos-7.git`

5. Accédez au nouveau répertoire: `cd centos-7`

6. Exécutez le script: `sudo ./centos-setup.sh --setup`

7. Prenez une tasse de café pendant que le script fait tout le travail.

8. Redémarrez.







## Personnalisation d'un serveur CentOS

Transformer une installation CentOS minimale en serveur fonctionnel revient toujours
jusqu'à une série d'opérations plus ou moins longues. Votre kilométrage peut
varient bien sûr, mais voici ce que je fais habituellement sur une nouvelle installation CentOS:

* Personnalisez le shell Bash: invite, alias, etc.

* Personnalisez l'éditeur Vim.

* Configurer les référentiels officiels et tiers.

* Installez un ensemble complet d'outils de ligne de commande.

* Supprimez quelques paquets inutiles.

* Autorisez l'utilisateur administrateur à accéder aux journaux système.

* Désactivez IPv6 et reconfigurez certains services en conséquence.
  
* Configurez un mot de passe persistant pour `sudo`.

* Etc.


Le script `centos-setup.sh` effectue toutes ces opérations.

Configurez Bash et Vim et définissez une résolution de console par défaut plus lisible:


```
# ./centos-setup.sh --shell
```

Configurer les référentiels officiels et tiers:


```
# ./centos-setup.sh --repos
```

Installez les groupes de packages `Core` et` Base` avec quelques outils supplémentaires:


```
# ./centos-setup.sh --extra
```

Supprimez quelques packages inutiles:

```
# ./centos-setup.sh --prune
```

Autorisez l'utilisateur administrateur à accéder aux journaux système:

```
# ./centos-setup.sh --logs
```

Désactivez IPv6 et reconfigurez les services de base en conséquence:


```
# ./centos-setup.sh --ipv4
```

Configurer la persistance du mot de passe pour sudo:

```
# ./centos-setup.sh --sudo
```

Effectuez tout ce qui précède en une seule fois:

```
# ./centos-setup.sh --setup
```

Supprimez les packages et revenez à un système de base amélioré:

```
# ./centos-setup.sh --strip
```

Afficher le message d'aide:

```
# ./centos-setup.sh --help
```

Si vous voulez savoir ce qui se passe exactement sous le capot, ouvrez un deuxième terminal
et afficher les journaux:


```
$ tail -f /tmp/centos-setup.log
```

