FROM frolvlad/alpine-glibc:latest

ENV MAVEN_VERSION=3.3.9
ENV LANG C.UTF-8
ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk
ENV PATH $PATH:/usr/lib/jvm/java-1.8-openjdk/jre/bin:/usr/lib/jvm/java-1.8-openjdk/bin
ENV JAVA_VERSION 8u151
ENV JAVA_ALPINE_VERSION 8.151.12-r0

ENV OC_VERSION=v3.6.0 \
    OC_TAG_SHA=c4dd4cf \
    BUILD_DEPS='tar gzip' \
    RUN_DEPS='bash curl git ca-certificates gettext procps'

RUN apk --no-cache add $BUILD_DEPS $RUN_DEPS openjdk8="$JAVA_ALPINE_VERSION" && \
    curl -sLo /tmp/oc.tar.gz https://github.com/openshift/origin/releases/download/${OC_VERSION}/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit.tar.gz && \
    tar xzvf /tmp/oc.tar.gz -C /tmp/ && \
    mv /tmp/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit/oc /usr/local/bin/ && \
    rm -rf /tmp/oc.tar.gz /tmp/openshift-origin-client-tools-${OC_VERSION}-${OC_TAG_SHA}-linux-64bit && \
    apk del $BUILD_DEPS \
    && echo "securerandom.source=file:/dev/urandom" >> /usr/lib/jvm/default-jvm/jre/lib/security/java.security \
    && mkdir -p /usr/local/maven /opt/app \
	&& chown -R 1001:1001 /opt/app \
	&& curl -jksSL -o /tmp/apache-maven.tar.gz https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz \
	&& gunzip /tmp/apache-maven.tar.gz \
	&& tar -C /usr/local -xf /tmp/apache-maven.tar \
	&& ln -s /usr/local/apache-maven-$MAVEN_VERSION/bin/mvn /usr/bin/mvn \
	&& rm -rf /tmp/* /var/cache/apk/*
    
ENV HOME=/home/jenkins

RUN mkdir -p ${HOME} \
    && mkdir -p $HOME/.m2 \ 
    && adduser -s /bin/sh -u 1001 -G root -h ${HOME} -S -D default \
    && chown -R 1001:0 ${HOME} \
    && mkdir -p /var/lib/jenkins && \
    chown -R 1001:0 /var/lib/jenkins && \
    chmod -R g+w /var/lib/jenkins

# Copy the entrypoint
ADD contrib/bin/* /usr/local/bin/
RUN chmod -R 755 /usr/local/bin

USER 1001

# Run the JNLP client by default
ENTRYPOINT ["/usr/local/bin/run-jnlp-client"]
