FROM php:7.3-apache

ENV DOWNLOAD_URL https://download.limesurvey.org/lts-releases/limesurvey3.22.28+200728.zip
ENV DOWNLOAD_SHA256 0edfedd9fdb7c4579ac308f2bf0a22a14e35553f05a110c9fd2cada70793c174

# install the PHP extensions we need
RUN apt-get update && apt-get install -y unzip libc-client-dev libfreetype6-dev libmcrypt-dev libpng-dev libjpeg-dev libldap2-dev zlib1g-dev libkrb5-dev libtidy-dev libzip-dev libsodium-dev && rm -rf /var/lib/apt/lists/* \
	&& docker-php-ext-configure gd --with-freetype-dir=/usr/include/  --with-png-dir=/usr --with-jpeg-dir=/usr \
	&& docker-php-ext-install gd mysqli pdo pdo_mysql opcache zip iconv tidy \
    && docker-php-ext-configure ldap --with-libdir=lib/$(gcc -dumpmachine)/ \
    && docker-php-ext-install ldap \
    && docker-php-ext-configure imap --with-imap-ssl --with-kerberos \
    && docker-php-ext-install imap \
    && docker-php-ext-install sodium \
    && pecl install mcrypt-1.0.3 \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-install exif

RUN a2enmod rewrite

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
		echo 'opcache.enable_cli=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN set -x; \
    curl -SL "$DOWNLOAD_URL" -o /tmp/lime.zip; \
    echo "$DOWNLOAD_SHA256 /tmp/lime.zip" | sha256sum -c -; \
    unzip /tmp/lime.zip -d /tmp; \
    mv /tmp/lime*/* /var/www/html/; \
    mv /tmp/lime*/.[a-zA-Z]* /var/www/html/; \
    rm /tmp/lime.zip; \
    rmdir /tmp/lime*; \
    chown -R www-data:www-data /var/www/html

#Set PHP defaults for Limesurvey (allow bigger uploads)
RUN { \
		echo 'memory_limit=256M'; \
		echo 'upload_max_filesize=128M'; \
		echo 'post_max_size=128M'; \
		echo 'max_execution_time=120'; \
        echo 'max_input_vars=10000'; \
        echo 'date.timezone=UTC'; \
	} > /usr/local/etc/php/conf.d/uploads.ini

VOLUME ["/var/www/html/plugins"]
VOLUME ["/var/www/html/upload"]

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat

# ENTRYPOINT resets CMD
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
