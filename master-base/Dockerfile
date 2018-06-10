FROM jalammas/openjdk8-alpine-oc:v3.6

LABEL k8s.io.description="Jenkins is a continuous integration server" \
      k8s.io.display-name="Jenkins 2" \
      openshift.io.expose-services="8080:http" \
      openshift.io.tags="jenkins,jenkins2,ci" \
      io.openshift.s2i.scripts-url=image:////usr/local/bin

# 8080 for main web interface, 50000 for slave agents
EXPOSE 8080 50000

# Jenkins image for OpenShift

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT 50000
ENV HOME /var/jenkins_home
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL https://updates.jenkins.io/experimental
# jenkins version being bundled in this docker image
ENV JENKINS_VERSION 2.107.3
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=17a9e509bec5b16bde5b50bc7f59d5f1e458a55fe433deb86fd73b865bf89ab8
# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

USER root

RUN mkdir -p $JENKINS_HOME \ 
    && chown -R 1001:0 $JENKINS_HOME \
    && mkdir -p /usr/share/jenkins/ref \
    && curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
    && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

# `/usr/share/jenkins/ref/` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.

COPY jenkins-support /usr/local/bin/jenkins-support
COPY jenkins.sh /usr/local/bin/jenkins.sh
COPY jenkins.sh /usr/local/bin/run
COPY assemble /usr/local/bin/assemble
# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY install-plugins.sh /usr/local/bin/install-plugins.sh
COPY ./contrib/jenkins /usr/local/bin
COPY config /usr/share/jenkins/ref
ADD release.version /tmp/release.version


RUN chmod -R 755 /usr/local/bin \
    && /usr/local/bin/fix-permissions /var/jenkins_home \
    && chmod -R 777 /var/jenkins_home \
    && /usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/base-plugins.txt \
    && /usr/local/bin/fix-permissions /usr/share/jenkins/ref \
    && chown -R 1001:0 /usr/share/jenkins/ref \
    && chmod 664 /etc/passwd

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME ["/var/jenkins_home"]

USER 1001

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/run"]

