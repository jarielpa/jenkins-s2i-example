FROM frolvlad/alpine-glibc:latest

ENV OC_VERSION=v3.6.0 \
    OC_TAG_SHA=c4dd4cf \
    BUILD_DEPS='tar gzip' \
    RUN_DEPS='curl ca-certificates gettext openjdk8=8.151.12-r0 git'

RUN apk --no-cache add $BUILD_DEPS $RUN_DEPS && \
    curl -sLo /tmp/oc.tar.gz https://github.com/openshift/origin/releases/download/${OC_VERSION}/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit.tar.gz && \
    tar xzvf /tmp/oc.tar.gz -C /tmp/ && \
    mv /tmp/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit/oc /usr/local/bin/ && \
    rm -rf /tmp/oc.tar.gz /tmp/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit && \
    apk del $BUILD_DEPS \
    && echo "securerandom.source=file:/dev/urandom" >> /usr/lib/jvm/default-jvm/jre/lib/security/java.security
    
ENV HOME=/home/jenkins

RUN mkdir -p ${HOME} \
    && adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default \
    && chown -R 1001:0 ${HOME}
    mkdir -p /var/lib/jenkins && \
    chown -R 1001:0 /var/lib/jenkins && \
    chmod -R g+w /var/lib/jenkins

# Copy the entrypoint
#COPY configuration/* /var/lib/jenkins/
USER 1001

# Run the JNLP client by default
# To use swarm client, specify "/var/lib/jenkins/run-swarm-client" as Command
#ENTRYPOINT ["/var/lib/jenkins/run-jnlp-client"]
