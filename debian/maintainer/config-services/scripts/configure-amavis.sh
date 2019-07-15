#!/bin/sh

touch /etc/postfix/destination_domains
cp snippets/amavis-60-ispman /etc/amavis/conf.d/60-ispman
cat snippets/amavis-contentfilter-postfix >> /etc/postfix/main.cf
addgroup clamav amavis

