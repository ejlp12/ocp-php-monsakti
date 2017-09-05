FROM registry.access.redhat.com/rhel

# =============================================================================
# naqoda/centos-apache-php
#
# CentOS-7, Apache 2.2, PHP 5.6, Ioncube, MYSQL, DB2
# 
# =============================================================================
#FROM centos:centos7

#MAINTAINER Naqoda <info@naqoda.com>
MAINTAINER EJLP <ejlp12@gmail.com>

ARG uid=1000

# -----------------------------------------------------------------------------
# Import the RPM GPG keys for Repositories
# -----------------------------------------------------------------------------
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
	&& rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm

#RUN echo -e "[epel]\nname=epel\nenabled=1\nbaseurl=https://dl.fedoraproject.org/pub/epel/7/x86_64/\ngpgcheck=0" > /etc/yum.repos.d/epel.repo  

# -----------------------------------------------------------------------------
# Apache + PHP
# -----------------------------------------------------------------------------
RUN \
    yum repolist > /dev/null && \
    yum install -y yum-utils epel-release && \
    yum-config-manager --disable \* &> /dev/null && \
    yum-config-manager --enable rhel-server-rhscl-7-rpms && \
    yum-config-manager --enable rhel-7-server-rpms && \
    yum-config-manager --enable rhel-7-server-optional-rpms && \
    yum-config-manager --enable epel && \
    yum-config-manager --enable webtatic && \
    INSTALL_PKGS="gcc gcc-c++ httpd mod_ssl php56w php56w-cli php56w-devel php56w-mysql \
    php56w-pdo php56w-mbstring php56w-soap php56w-gd php56w-xml php56w-pecl-apcu unzip libaio" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    rm -rf /var/cache/yum/* && \
    yum clean all

# -----------------------------------------------------------------------------
# UTC Timezone & Networking
# -----------------------------------------------------------------------------
RUN ln -sf /usr/share/zoneinfo/UTC /etc/localtime \
	&& echo "NETWORKING=yes" > /etc/sysconfig/network


#COPY modules/php56/* /usr/lib64/php/modules/

# Global Apache configuration changes
# Disable Apache directory indexes
# Disable Apache language based content negotiation
# Disable all Apache modules and enable the minimum
# Enable ServerStatus access via /_httpdstatus to local client
# Apache tuning
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^ServerSignature On$~ServerSignature Off~g' \
	-e 's~^ServerTokens OS$~ServerTokens Prod~g' \
	-e 's~^DirectoryIndex \(.*\)$~DirectoryIndex \1 index.php~g' \
	-e 's~^Group apache$~Group app~g' \
	-e 's~^IndexOptions \(.*\)$~#IndexOptions \1~g' \
	-e 's~^IndexIgnore \(.*\)$~#IndexIgnore \1~g' \
	-e 's~^AddIconByEncoding \(.*\)$~#AddIconByEncoding \1~g' \
	-e 's~^AddIconByType \(.*\)$~#AddIconByType \1~g' \
	-e 's~^AddIcon \(.*\)$~#AddIcon \1~g' \
	-e 's~^DefaultIcon \(.*\)$~#DefaultIcon \1~g' \
	-e 's~^ReadmeName \(.*\)$~#ReadmeName \1~g' \
	-e 's~^HeaderName \(.*\)$~#HeaderName \1~g' \
	-e 's~^LanguagePriority \(.*\)$~#LanguagePriority \1~g' \
	-e 's~^ForceLanguagePriority \(.*\)$~#ForceLanguagePriority \1~g' \
	-e 's~^AddLanguage \(.*\)$~#AddLanguage \1~g' \
	-e 's~^\(LoadModule .*\)$~#\1~g' \
	-e 's~^\(#LoadModule version_module modules/mod_version.so\)$~\1\n#LoadModule reqtimeout_module modules/mod_reqtimeout.so~g' \
	-e 's~^#LoadModule mime_module ~LoadModule mime_module ~g' \
	-e 's~^#LoadModule log_config_module ~LoadModule log_config_module ~g' \
	-e 's~^#LoadModule setenvif_module ~LoadModule setenvif_module ~g' \
	-e 's~^#LoadModule status_module ~LoadModule status_module ~g' \
	-e 's~^#LoadModule authz_host_module ~LoadModule authz_host_module ~g' \
	-e 's~^#LoadModule dir_module ~LoadModule dir_module ~g' \
	-e 's~^#LoadModule alias_module ~LoadModule alias_module ~g' \
	-e 's~^#LoadModule rewrite_module ~LoadModule rewrite_module ~g' \
	-e 's~^#LoadModule expires_module ~LoadModule expires_module ~g' \
	-e 's~^#LoadModule deflate_module ~LoadModule deflate_module ~g' \
	-e 's~^#LoadModule headers_module ~LoadModule headers_module ~g' \
	-e 's~^#LoadModule alias_module ~LoadModule alias_module ~g' \
	-e '/#<Location \/server-status>/,/#<\/Location>/ s~^#~~' \
	-e '/<Location \/server-status>/,/<\/Location>/ s~Allow from .example.com~Allow from localhost 127.0.0.1~' \
	-e 's~^StartServers \(.*\)$~StartServers 3~g' \
	-e 's~^MinSpareServers \(.*\)$~MinSpareServers 3~g' \
	-e 's~^MaxSpareServers \(.*\)$~MaxSpareServers 3~g' \
	-e 's~^ServerLimit \(.*\)$~ServerLimit 10~g' \
	-e 's~^MaxClients \(.*\)$~MaxClients 10~g' \
	-e 's~^MaxRequestsPerChild \(.*\)$~MaxRequestsPerChild 1000~g' \
	/etc/httpd/conf/httpd.conf

# -----------------------------------------------------------------------------
# Disable the default SSL Virtual Host
# -----------------------------------------------------------------------------
RUN sed -i \
	-e '/<VirtualHost _default_:443>/,/#<\/VirtualHost>/ s~^~#~' \
	/etc/httpd/conf.d/ssl.conf

# -----------------------------------------------------------------------------
# Limit process for the application user
# -----------------------------------------------------------------------------
RUN { \
		echo ''; \
		echo $'apache\tsoft\tnproc\t30'; \
		echo $'apache\thard\tnproc\t50'; \
		echo $'app\tsoft\tnproc\t30'; \
		echo $'app\thard\tnproc\t50'; \
	} >> /etc/security/limits.conf

# -----------------------------------------------------------------------------
# Global PHP configuration changes
# -----------------------------------------------------------------------------
RUN sed -i \
	-e 's~^;date.timezone =$~date.timezone = UTC~g' \
	-e 's~^;user_ini.filename =$~user_ini.filename =~g' \
	-e 's~^;always_populate_raw_post_data = -1$~always_populate_raw_post_data = -1~g' \
        -e 's~^short_open_tag = Off~short_open_tag = On~g' \
	/etc/php.ini


# -----------------------------------------------------------------------------
# Add default service users
# -----------------------------------------------------------------------------
RUN useradd -u ${uid} -d /var/www/app -m app \
	&& usermod -a -G app apache

# -----------------------------------------------------------------------------
# Add a symbolic link to the app users home within the home directory &
# Create the initial directory structure
# -----------------------------------------------------------------------------
RUN ln -s /var/www/app /home/app \
	&& mkdir -p /var/www/app/{public_html,var/{log,session}}

# -----------------------------------------------------------------------------
# Virtual hosts configuration
# -----------------------------------------------------------------------------
ADD etc/httpd/conf.d/ /etc/httpd/conf.d


# Oracle instantclient
ADD instantclient-basic-linux.x64-12.1.0.2.0.zip /tmp/
ADD instantclient-sdk-linux.x64-12.1.0.2.0.zip /tmp/
ADD instantclient-sqlplus-linux.x64-12.1.0.2.0.zip /tmp/

RUN unzip /tmp/instantclient-basic-linux.x64-12.1.0.2.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sdk-linux.x64-12.1.0.2.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sqlplus-linux.x64-12.1.0.2.0.zip -d /usr/local/
RUN ln -s /usr/local/instantclient_12_1 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/libclntsh.so.12.1 /usr/local/instantclient/libclntsh.so
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus
RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8-2.0.12
RUN echo "extension=oci8.so" > /etc/php.d/oci8.ini 



# -----------------------------------------------------------------------------
# Set permissions
# -----------------------------------------------------------------------------
RUN chown -R app:app /var/www/app \
	&& chmod 770 /var/www/app \
	&& chmod -R g+w /var/www/app/var

# -----------------------------------------------------------------------------
# Remove packages
# -----------------------------------------------------------------------------
RUN yum -y remove \
	gcc \
	gcc-c++ \
	&& rm -rf /var/cache/yum/* \
	&& yum clean all

# -----------------------------------------------------------------------------
# Set default environment variables used to identify the service container
# -----------------------------------------------------------------------------
ENV SERVICE_UNIT_APP_GROUP app-1 
ENV	SERVICE_UNIT_LOCAL_ID 1
ENV	SERVICE_UNIT_INSTANCE 1

# -----------------------------------------------------------------------------
# Set default environment variables used to configure the service container
# -----------------------------------------------------------------------------
ENV APACHE_SERVER_ALIAS "" 
ENV	APACHE_SERVER_NAME app-1.local 
ENV	APP_HOME_DIR /var/www/app
ENV	DATE_TIMEZONE UTC 
ENV	HTTPD /usr/sbin/httpd 
ENV	SERVICE_USER app 
ENV	SERVICE_USER_GROUP app 
ENV	SERVICE_USER_PASSWORD "" 
ENV	SUEXECUSERGROUP false 
ENV	TERM xterm
ENV DB_MYSQL_PORT_3306_TCP_ADDR ""
ENV DB_MYSQL_PORT_3306_TCP_PORT ""

# -----------------------------------------------------------------------------
# Set locale
# -----------------------------------------------------------------------------
RUN localedef -i en_GB -f UTF-8 en_GB.UTF-8
ENV LANG en_GB.UTF-8

# -----------------------------------------------------------------------------
# Set ports
# -----------------------------------------------------------------------------
EXPOSE 80 443

# -----------------------------------------------------------------------------
# Copy files into place
# -----------------------------------------------------------------------------
#ADD index.php /var/www/app/public_html/index.php

RUN yum -y install git
RUN git clone https://github.com/ejlp12/monsakti-dev.git /var/www/app/public_html
RUN yum -y remove git && \
    yum clean all

CMD ["/usr/sbin/httpd", "-DFOREGROUND"]

