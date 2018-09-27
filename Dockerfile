# Docker for modified BOCA

FROM ubuntu:trusty

RUN apt -y update
RUN apt -y install tzdata locales software-properties-common python-software-properties --no-install-recommends
RUN echo "America/Sao_Paulo" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata
RUN locale-gen en_US en_US.UTF-8
RUN locale -a
ENV LANGUAGE=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
RUN locale-gen en_US.UTF-8
RUN DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales

RUN apt -y install postgresql-client apache2 libapache2-mod-php5 php5 php5-cli php5-cgi php5-gd php5-mcrypt php5-pgsql mcrypt git makepasswd

ENV GIT_SSL_NO_VERIFY true
#RUN git clone https://gitlab.inf.ufsm.br/jvlima/boca.git /var/www/boca
RUN git clone https://github.com/joao-lima/boca.git /var/www/boca

ENV APACHE_CONFDIR /etc/apache2
ENV APACHE_ENVVARS $APACHE_CONFDIR/envvars
RUN echo APACHE_ENVVARS
RUN set -ex \
	\
# generically convert lines like
#   export APACHE_RUN_USER=www-data
# into
#   : ${APACHE_RUN_USER:=www-data}
#   export APACHE_RUN_USER
# so that they can be overridden at runtime ("-e APACHE_RUN_USER=...")
	&& sed -ri 's/^export ([^=]+)=(.*)$/: ${\1:=\2}\nexport \1/' "$APACHE_ENVVARS" \
	\
# setup directories and permissions
	&& . "$APACHE_ENVVARS" \
	&& for dir in \
		"$APACHE_LOCK_DIR" \
		"$APACHE_RUN_DIR" \
		"$APACHE_LOG_DIR" \
		/var/www/html \
	; do \
		rm -rvf "$dir" \
		&& mkdir -p "$dir" \
		&& chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"; \
	done

# Apache + PHP requires preforking Apache for best results
RUN a2dismod mpm_event && a2enmod mpm_prefork
RUN php5enmod mcrypt
# logs should go to stdout / stderr
RUN set -ex \
	&& . "$APACHE_ENVVARS" \
	&& ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log" \
        && ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log" \
	&& ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"

# Add startup script to the container.
COPY apache2-foreground /usr/local/bin/
COPY startup.sh /startup.sh

WORKDIR /var/www/boca
RUN cp tools/etc/apache2/conf.d/boca /etc/apache2/sites-enabled/000-boca.conf
RUN echo bocadir=/var/www/boca > /etc/boca.conf

RUN chown -R www-data:www-data /var/www/boca
RUN chmod 600 /var/www/boca/src/private/conf.php

EXPOSE 80
CMD ["/bin/bash", "/startup.sh"]

