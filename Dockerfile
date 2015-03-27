From ubuntu:trusty
MAINTAINER Christoph Dwertmann

RUN DEBIAN_FRONTEND=noninteractive \
    sed -i 's#http://archive.ubuntu#http://au.archive.ubuntu#' /etc/apt/sources.list && \
    apt-get update -qq && \
    apt-get -y install supervisor postfix sasl2-bin opendkim opendkim-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add files
ADD assets/install.sh /opt/install.sh
ADD assets/filter.sh /usr/local/bin/filter.sh

# Run
CMD /opt/install.sh;/usr/bin/supervisord -c /etc/supervisor/supervisord.conf