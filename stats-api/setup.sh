#!/usr/bin/env bash
# One-time setup: adds the standard Laravel 11 skeleton around the files in this folder.
# Needs PHP 8.3 and Composer. Afterwards commit everything (vendor/ and .env are git-ignored),
# including composer.json and composer.lock.
set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp -d)"
composer create-project "laravel/laravel:^12.0" "$tmp/app" --prefer-dist --no-interaction

# -n: never overwrite the files that already exist here (controller, routes, bootstrap/app.php, tests)
cp -rn "$tmp/app/." . || true
rm -rf "$tmp"
rm -f tests/Unit/ExampleTest.php tests/Feature/ExampleTest.php .env

composer config platform.php 8.4.1
composer require predis/predis --no-interaction
composer require --dev larastan/larastan:^3.0 --no-interaction

test -f composer.lock && echo "Done. Now run: vendor/bin/phpunit && vendor/bin/phpstan analyse"
