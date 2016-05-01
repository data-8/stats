FROM     ubuntu:14.04

# Update system and install required packages
RUN	apt-get update && apt-get upgrade

RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y debconf-utils expect
RUN     echo graphite-carbon graphite-carbon/postrm_remove_databases boolean false | debconf-set-selections

RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y build-essential graphite-web graphite-carbon python-dev apache2 libapache2-mod-wsgi libpq-dev python-psycopg2 curl apt-transport-https

# Configure Carbon
ADD	./carbon/storage-schemas.conf /etc/carbon/storage-schemas.conf
ADD	./carbon/graphite-carbon /etc/default/graphite-carbon
ADD	./carbon/carbon.conf /etc/carbon/carbon.conf
ADD	./carbon/storage-aggregation.conf /etc/carbon/storage-aggregation.conf
#RUN	service carbon-cache start

# Install and Configure PostgreSQL
#RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get -y install postgresql
#USER	postgres
#RUN	echo break 2
#RUN	/etc/init.d/postgresql start && psql --command "CREATE USER graphite WITH PASSWORD 'Funcats!';" && psql --command "CREATE DATABASE graphite WITH OWNER graphite;" && psql --command "CREATE DATABASE grafana WITH OWNER graphite;"
#USER	root 

# Configure graphite-web application
ADD	./graphite/local_settings.py /etc/graphite/local_settings.py
ADD	./syncdb.exp /etc/syncdb.exp
#RUN	/etc/init.d/postgresql status || sudo -u postgres /etc/init.d/postgresql start
#RUN	/etc/init.d/postgresql status || echo NOT RUNNING
RUN	expect /etc/syncdb.exp

# Configure Apache for Graphite
RUN	cp /usr/share/graphite-web/apache2-graphite.conf /etc/apache2/sites-available
ADD	./apache/apache2-graphite.conf /etc/apache2/sites-available/apache2-graphite.conf
ADD	./apache/ports.conf /etc/apache2/ports.conf
RUN	a2dissite 000-default
RUN	a2ensite apache2-graphite
#RUN	service apache2 start

# Install and Configure Grafana
RUN	echo 'deb https://packagecloud.io/grafana/stable/debian/ wheezy main' |  tee -a /etc/apt/sources.list
RUN	curl https://packagecloud.io/gpg.key | sudo apt-key add -
RUN	apt-get update && DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y grafana
ADD	./grafana/grafana.ini /etc/grafana/grafana.ini
RUN	a2enmod proxy proxy_http xml2enc
ADD	./grafana/apache2-grafana.conf /etc/apache2/sites-available/apache2-grafana.conf
RUN	a2ensite apache2-grafana
RUN	update-rc.d grafana-server defaults 95 10 
#RUN	service grafana-server start
#RUN	service apache2 restart

# Install and Configure Statsd
RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y git nodejs devscripts debhelper dh-systemd
RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y npm
RUN	mkdir ~/build && cd ~/build && git clone https://github.com/etsy/statsd.git
RUN	cd ~/build/statsd && dpkg-buildpackage
#RUN	service carbon-cache stop
RUN	cd ~/build && dpkg -i statsd*.deb
#RUN	service statsd stop && service carbon-cache start
ADD	./statsd/localConfig.js /etc/statsd/localConfig.js

# Add CMD file
#ADD	./run/start /start

# Setup supervisor
RUN	DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y supervisor
RUN     DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=high apt-get install -y node
ADD     ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# ---------------- #`
#   Expose Ports   #
# ---------------- #

# Grafana
EXPOSE  80

# StatsD UDP port
EXPOSE  8125/udp

# Graphite web port
EXPOSE 8080

CMD ["/usr/bin/supervisord"]
