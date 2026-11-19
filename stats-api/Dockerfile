FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --prefer-dist --no-progress --no-autoloader
COPY . .
RUN composer dump-autoload --no-dev --no-scripts --optimize

FROM php:8.4-fpm-alpine

RUN apk add --no-cache nginx postgresql-libs oniguruma \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS postgresql-dev oniguruma-dev \
    && docker-php-ext-install pdo_pgsql mbstring bcmath \
    && apk del .build-deps
WORKDIR /var/www/html
COPY --from=vendor /app ./
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/zz-app.conf
COPY docker/start.sh /start.sh
ARG GIT_COMMIT=dev
ENV APP_ENV=production APP_DEBUG=false LOG_CHANNEL=stderr REDIS_CLIENT=predis GIT_COMMIT=${GIT_COMMIT}
RUN chmod +x /start.sh \
 && mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache /var/lib/nginx/tmp /var/log/nginx \
 && chown -R www-data:www-data storage bootstrap/cache /var/lib/nginx /var/log/nginx
USER www-data
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1
CMD ["/start.sh"]
