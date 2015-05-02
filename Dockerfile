FROM java:7

## ENV attributes for proxy. These HAVE to get overwritten when you run the container
#ENV no_proxy localhost,127.0.0.0/8
#ENV http_proxy http://proxy.ecos.aws:8080
#ENV https_proxy http://proxy.ecos.aws:8080

# Configuration variables.
ENV JIRA_HOME     /var/local/atlassian/jira
ENV JIRA_INSTALL  /usr/local/atlassian/jira
ENV JIRA_VERSION  6.4.2

## SSH 
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:screencast' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

# Install Atlassian JIRA and helper tools and setup initial home
# directory structure.
RUN set -x \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends libtcnative-1 xmlstarlet \
    && apt-get install --quiet --yes supervisor \
    && apt-get clean \
    && mkdir -p                "${JIRA_HOME}" \
    && chmod -R 700            "${JIRA_HOME}" \
    && chown -R daemon:daemon  "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                "http://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && chmod -R 700            "${JIRA_INSTALL}/conf" \
    && chmod -R 700            "${JIRA_INSTALL}/logs" \
    && chmod -R 700            "${JIRA_INSTALL}/temp" \
    && chmod -R 700            "${JIRA_INSTALL}/work" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/conf" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/logs" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/temp" \
    && chown -R daemon:daemon  "${JIRA_INSTALL}/work" \
    && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    # Add mysql driver
    && curl -sSL http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.32.tar.gz -o /tmp/mysql-connector-java.tar.gz \
    && tar xzf /tmp/mysql-connector-java.tar.gz -C /tmp \
    && cp /tmp/mysql-connector-java-5.1.32/mysql-connector-java-5.1.32-bin.jar ${JIRA_INSTALL}/lib/

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER daemon:daemon

# Expose default HTTP connector port.
EXPOSE 8080
# for ssh into this docker container
EXPOSE 22

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/local/atlassian/jira"]

# Set the default working directory as the installation directory.
WORKDIR ${JIRA_HOME}

USER root:root
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# Run Atlassian JIRA as a foreground process by default.
ENTRYPOINT ["/usr/bin/supervisord"]
