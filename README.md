docker-postfix
==============

run postfix with smtp authentication (sasldb) in a docker container.
TLS and OpenDKIM support are optional.

## Command line

	docker run -p 25:25 -p 587:587 -e maildomain= -e mydestination= -e smtp_user=user:pwd -v /root/domainkeys:/etc/opendkim/domainkeys -v /root/certs:/etc/postfix/certs --name postfix -d  vault/postfix

## Note
+ Login credential should be set to (`username@mail.example.com`, `password`) in Smtp Client
+ You can assign the port of MTA on the host machine to one other than 25 ([postfix how-to](http://www.postfix.org/MULTI_INSTANCE_README.html))
+ Read the reference below to find out how to generate domain keys and add public key to the domain's DNS records
