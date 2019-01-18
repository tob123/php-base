ARG ALPINE_VER=3.8
FROM alpine:${ALPINE_VER}
###
ENV HTTP_PORT=8000
# use httpd-foreground as defined here: https://github.com/docker-library/httpd/blob/master/2.4/httpd-foreground
COPY httpd-foreground /usr/local/bin/
COPY httpd-custom.conf cis.conf /etc/apache2/conf.d/
COPY limitexcept /root/
ENV MY_DOC_ROOT=/var/www/localhost/htdocs
RUN apk --no-cache add \
    php7-apache2 \
    apache2 \
    php7 \
    curl; \
    sed -i "s/80/${HTTP_PORT}/g" /etc/apache2/httpd.conf ; \
    # change default logging to docker way of logging: stdout and stderror
    sed -i 's/logs\/error.log/\/proc\/self\/fd\/2/' /etc/apache2/httpd.conf ; \
    sed -i 's/logs\/access.log/\/proc\/self\/fd\/1/' /etc/apache2/httpd.conf; \
    mkdir /run/apache2; \
    chown apache:apache /run/apache2; \
    chmod 700 /run/apache2; \
    mkdir ${MY_DOC_ROOT}; \
    apk add --virtual build-dependencies gawk; \
    awk -i inplace '{ gsub(/MY_DOC_ROOT/,"'"${MY_DOC_ROOT}"'") }; { print }' /etc/apache2/conf.d/httpd-custom.conf; \
    apk del --purge build-dependencies ;\
    #CIS stuff for apache
#apply some cis baseline items for apache. 
#2.1auth related modules. authz_core and authz_host are needed for configuring grants on directories
    APACHECONF=/etc/apache2/httpd.conf; \
    sed -i 's/^LoadModule auth_basic_module/#LoadModule auth_basic_module/' ${APACHECONF}; \
    sed -i 's/^LoadModule authn_file_module/#LoadModule authn_file_module/' ${APACHECONF}; \
    sed -i 's/^LoadModule authz_user_module/#LoadModule authz_user_module/' ${APACHECONF}; \
    sed -i 's/^LoadModule authn_core_module/#LoadModule authn_core_module/' ${APACHECONF}; \
    sed -i 's/^LoadModule authz_groupfile_module/#LoadModule authz_groupfile_module/' ${APACHECONF}; \
#2.2,2.3,2.6 need no modifications: disabled by default
#2.4deactivate status
    sed -i 's/^LoadModule status_module/#LoadModule status_module/' ${APACHECONF}; \
#2.5deactivate autoindex
    sed -i 's/^LoadModule autoindex_module/#LoadModule autoindex_module/' ${APACHECONF}; \
#2.7 and 2.8drop some config files related to modules not needed:
    rm /etc/apache2/conf.d/userdir.conf; \
    rm /etc/apache2/conf.d/info.conf; \
#set options to none for default directories as recommended in 1.5
    sed -i 's/^    Options .*/    Options None/' ${APACHECONF}; \
#1.5.6 removal of test-cgi
    rm /var/www/localhost/cgi-bin/test-cgi; \
#1.5.7: set limit to valid http requests
    sed -i '/\<Directory /r /root/limitexcept' ${APACHECONF}; \
    rm /root/limitexcept; \
#1.6 increase logging verbosity
    sed -i 's/^LogLevel.*/LogLevel notice core:info/' ${APACHECONF}; \
#1.7 ssl is done elsewhere (not in this container)
#1.8
    sed -i 's/^ServerTokens.*/ServerTokens Prod/' ${APACHECONF}; \
    sed -i 's/^ServerSignature.*/ServerSignature Off/' ${APACHECONF}; \
    sed -i 's/^Timeout.*/Timeout 10/' /etc/apache2/conf.d/default.conf; \
# some php items
    PHPCONF=/etc/php7/php.ini; \
#hide php version from headers:
    sed -i 's/expose_php = On/expose_php = Off/' $PHPCONF; \
    chmod 755 /usr/local/bin/httpd-foreground
LABEL description="Apache/php Docker container without root gosu sudo or other wrappers that use root" \
      ALPINE="Alpine v${ALPINE_VER}" \
      maintainer="Appelo Solutions <tob@nice.eu>"

USER apache
CMD ["httpd-foreground"]
