#!/bin/sh
set -e
# Cache the config at start (not at build time) so Kubernetes environment variables are used.
php artisan config:cache
php-fpm -D
exec nginx -g 'daemon off;'
