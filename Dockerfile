From ubuntu:trusty
MAINTAINER Christoph Dwertmann

RUN apt-get update && apt-get -y install 
RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update -qq && \
    apt-get -y install supervisor postfix sasl2-bin opendkim opendkim-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Add files
ADD assets/install.sh /opt/install.sh
ADD assets/filter.sh /usr/local/bin/filter.sh

# Run
CMD /opt/install.sh;/usr/bin/supervisord -c /etc/supervisor/supervisord.conf