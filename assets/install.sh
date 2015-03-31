#!/bin/bash

#judgement
if [[ -a /etc/supervisor/conf.d/supervisord.conf ]]; then
  exit 0
fi

#supervisor
cat > /etc/supervisor/conf.d/supervisord.conf <<EOF
[supervisord]
nodaemon=false

[program:postfix]
command=/opt/postfix.sh

[program:rsyslog]
command=/usr/sbin/rsyslogd -n -c3
EOF

############
#  postfix
############
cat >> /opt/postfix.sh <<EOF
#!/bin/bash
service postfix start
busybox tail -F /var/log/mail.log
EOF
chmod +x /opt/postfix.sh
postconf -e myhostname=$mydestination
postconf -F '*/*/chroot = n'
postconf -e inet_protocols=ipv4
postconf -e message_size_limit=20480000
postconf -e 'home_mailbox=Maildir/'
postconf -e 'smtpd_banner=$myhostname Microsoft ESMTP MAIL Service, Version: 5.0.2195.1600 ready'
postconf -e disable_vrfy_command=yes

postconf -e virtual_alias_domains=$mydestination
postconf -e virtual_alias_maps=hash:/etc/postfix/virtual
postconf -X mydestination

# catch-all
cat >> /etc/postfix/virtual <<EOF
@$mydestination mail@localhost
EOF
postmap /etc/postfix/virtual

# protective markings filter
# /etc/postfix/master.cf
postconf -M protective_markings/unix='protective_markings unix - n n - - pipe flags=Rq user=mail null_sender= argv=/opt/filter.sh -f ${sender} -- ${recipient}'

############
# SASL SUPPORT FOR CLIENTS
# The following options set parameters needed by Postfix to enable
# Cyrus-SASL support for authentication of mail clients.
############
# /etc/postfix/main.cf
postconf -e smtpd_sasl_auth_enable=no
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination
# smtpd.conf
cat >> /etc/postfix/sasl/smtpd.conf <<EOF
pwcheck_method: auxprop
auxprop_plugin: sasldb
mech_list: PLAIN LOGIN CRAM-MD5 DIGEST-MD5 NTLM
EOF
# sasldb2
echo $smtp_user | tr , \\n > /tmp/passwd
while IFS=':' read -r _user _pwd; do
  echo $_pwd | saslpasswd2 -p -c -u $maildomain $_user
done < /tmp/passwd
chown postfix.sasl /etc/sasldb2

# swiftmail
postconf -M swiftmail/unix='swiftmail unix - n n - - pipe flags=Rq user=mail null_sender= argv=/opt/swiftmail.sh -f ${sender} -- ${recipient}'
postconf -M smtp/inet="smtp   inet   n   -   n   -   -   smtpd"
postconf -P "smtp/inet/content_filter=swiftmail:dummy"

############
# Enable TLS
############
if [[ -n "$(find /etc/postfix/certs -iname *.pem)" ]]; then
  # /etc/postfix/main.cf
  postconf -e smtpd_tls_cert_file=$(find /etc/postfix/certs -iname *.pem)
  postconf -e smtpd_tls_key_file=$(find /etc/postfix/certs -iname *.pem)
  # /etc/postfix/master.cf
  postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd"
  postconf -P "submission/inet/syslog_name=postfix/submission"
  postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
  postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
  postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING"
  postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination"
  postconf -P "submission/inet/content_filter=protective_markings:dummy"
  postconf -e smtpd_tls_ciphers=high
  postconf -e smtpd_tls_exclude_ciphers=aNULL,MD5
  postconf -e smtpd_tls_security_level=may
  # Preferred syntax with Postfix ≥ 2.5:
  postconf -e smtpd_tls_protocols=!SSLv2,!SSLv3
fi
# client TLS
postconf -e smtp_tls_security_level=may
postconf -e smtp_tls_ciphers=high
postconf -e smtp_tls_exclude_ciphers=aNULL,MD5
postconf -e smtp_tls_protocols=!SSLv2,!SSLv3

#############
#  opendkim
#############

if [[ -z "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  exit 0
fi
cat >> /etc/supervisor/conf.d/supervisord.conf <<EOF

[program:opendkim]
command=/usr/sbin/opendkim -f
EOF
# /etc/postfix/main.cf
postconf -e milter_protocol=2
postconf -e milter_default_action=accept
postconf -e smtpd_milters=inet:localhost:12301
postconf -e non_smtpd_milters=inet:localhost:12301

cat >> /etc/opendkim.conf <<EOF
AutoRestart             Yes
AutoRestartRate         10/1h
UMask                   002
Syslog                  yes
SyslogSuccess           Yes
LogWhy                  Yes

Canonicalization        relaxed/simple

ExternalIgnoreList      refile:/etc/opendkim/TrustedHosts
InternalHosts           refile:/etc/opendkim/TrustedHosts
KeyTable                refile:/etc/opendkim/KeyTable
SigningTable            refile:/etc/opendkim/SigningTable

Mode                    sv
PidFile                 /var/run/opendkim/opendkim.pid
SignatureAlgorithm      rsa-sha256

UserID                  opendkim:opendkim

Socket                  inet:12301@localhost
EOF
cat >> /etc/default/opendkim <<EOF
SOCKET="inet:12301@localhost"
EOF

cat >> /etc/opendkim/TrustedHosts <<EOF
127.0.0.1
localhost

*.$maildomain
EOF
cat >> /etc/opendkim/KeyTable <<EOF
bridge._domainkey.$maildomain $maildomain:bridge:$(find /etc/opendkim/domainkeys -iname *.private)
EOF
cat >> /etc/opendkim/SigningTable <<EOF
*@$maildomain bridge._domainkey.$maildomain
EOF
chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private) /etc/opendkim/domainkeys
