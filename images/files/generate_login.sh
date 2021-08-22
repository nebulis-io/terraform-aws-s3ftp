#!/bin/bash

FTP_DIR=/home/ftp
USER_CONFIG_DIR=/etc/vsftpd/vsftpd_user_conf

## Création du fichier de diff
diff /etc/vsftpd/.login_tmp.txt $FTP_DIR/login.txt | grep "<" | tr -s "<" " "  >> /etc/vsftpd/login_diff.txt
db_load -T -t hash -f /etc/vsftpd/login_diff.txt /etc/vsftpd/login_diff.db
chmod 600 /etc/vsftpd/login_diff.db

## Sauvegarde du fichier login.txt
cp $FTP_DIR/login.txt /etc/vsftpd/.login_tmp.txt

## Création du fichier db utilisateurs
rm /etc/vsftpd/login.db
db_load -T -t hash -f $FTP_DIR/login.txt /etc/vsftpd/login.db
chmod 600 /etc/vsftpd/login.db

## Pour tous les noms figurant dans la base de données:
for user in ` db_dump -p /etc/vsftpd/login.db | sed -n 's/^ //p' | sed -n '1,${p;n;}' `
do
    ## Création des répertoires personnels pour les utilisateurs virtuels
    if [ ! -d /home/ftp/$user ]; then
        echo ": ajout du répertoire personnel /home/ftp/$user pour l'utilisateur virtuel '$user'"
        mkdir -p $FTP_DIR/$user/
        mkdir -p $FTP_DIR/$user/in
        mkdir -p $FTP_DIR/$user/out
        chmod -R 770 $FTP_DIR/$user/
        chown -R ftp:nogroup $FTP_DIR/$user/
    else
        echo "[warning]: $FTP_DIR/$user: omission, ce répertoire existe déja."
    fi
    ## Mise en place chroot des utilisateurs virtuels
    if ! grep -q "^local_root=" $USER_CONFIG_DIR/$user 2>/dev/null; then
        echo ": on chroote '$user'"
        echo "local_root=/home/ftp/$user" >> $USER_CONFIG_DIR/$user
    echo "anon_world_readable_only=NO" >>  $USER_CONFIG_DIR/$user
    echo "write_enable=YES" >>  $USER_CONFIG_DIR/$user
        echo "anon_upload_enable=YES" >>  $USER_CONFIG_DIR/$user
        echo "anon_mkdir_write_enable=YES" >>  $USER_CONFIG_DIR/$user
        echo "anon_other_write_enable=YES" >>  $USER_CONFIG_DIR/$user
    else
        echo "[warning]: $USER_CONFIG_DIR/$user: '$user' est déjà en chroot."
    fi
done
    
## Suppression des configurations personnelles pour les utilisateurs virtuels
for user in ` db_dump -p /etc/vsftpd/login_diff.db | sed -n 's/^ //p' | sed -n '1,${p;n;}' `
do
    echo ": suppression de la configuration personnelle pour l'utilisateur virtuel '$user'"
    rm -rf /etc/vsftpd/vsftpd_user_conf/$user
done

## Suppression des fichiers temporaires
rm /etc/vsftpd/login_diff.txt
rm /etc/vsftpd/login_diff.db