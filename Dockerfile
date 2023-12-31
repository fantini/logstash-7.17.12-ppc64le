FROM centos:7 as build

RUN yum update -y &&\
  yum install -y git make unzip tar ant ruby gcc-c++ java-11-openjdk-devel wget gzip procps shadow-utils zip which

ENV JAVA_HOME="/usr/lib/jvm/java-11-openjdk"
ENV PATH="$PATH:$JAVA_HOME"

# Install latest version of Ruby using rvm
RUN curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
RUN curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -
RUN curl -sSL https://get.rvm.io | bash -s stable --ruby
RUN source /usr/local/rvm/scripts/rvm
RUN /bin/bash -l -c "gem install rake bundler"

# Install jRuby
WORKDIR /usr/local/src
RUN /bin/bash -l -c "rvm install jruby-9.1.12.0"

WORKDIR /usr/local/src
RUN git clone https://github.com/elastic/logstash.git
WORKDIR logstash
RUN git checkout v7.17.12

RUN sed -i '2d' ./rakelib/artifacts.rake
RUN /bin/bash -l -c "rake artifact:no_bundle_jdk_tar"


FROM registry.redhat.io/ubi8/ubi

RUN yum update -y &&\
  yum install -y java-11-openjdk-devel which &&\
  yum clean all

ENV LS_JAVA_HOME=/usr/lib/jvm/java-11-openjdk
ENV PATH=$PATH:$LS_JAVA_HOME

RUN groupadd --gid 1000 logstash &&\
  adduser --uid 1000 --gid 1000 --home-dir /usr/share/logstash --no-create-home logstash

WORKDIR /usr/share

COPY --from=build /usr/local/src/logstash/build/logstash-7.17.12-SNAPSHOT.tar.gz ./

#COPY logstash-7.17.12-SNAPSHOT.tar.gz.* ./
#RUN cat logstash-7.17.12-SNAPSHOT.tar.gz.* > logstash-7.17.12-SNAPSHOT.tar.gz

#RUN tar zxf logstash-7.17.12-SNAPSHOT.tar.gz &&\
#  rm logstash-7.17.12-SNAPSHOT.tar.gz &&\
#  rm -R /usr/share/logstash-7.17.12-SNAPSHOT/jdk &&\
#  mv /usr/share/logstash-7.17.12-SNAPSHOT /usr/share/logstash

RUN tar zxf logstash-7.17.12-SNAPSHOT.tar.gz &&\
  rm logstash-7.17.12-SNAPSHOT.tar.gz &&\
  mv /usr/share/logstash-7.17.12-SNAPSHOT /usr/share/logstash

RUN logstash/bin/logstash-plugin install logstash-output-exec

RUN chmod 0664 /usr/share/logstash/logstash-core/lib/logstash/build.rb &&\
  chown -R logstash:logstash /usr/share/logstash/ &&\
  chown -R logstash:root /usr/share/logstash/ & \
  chmod -R g=u /usr/share/logstash/ &&\
  find /usr/share/logstash -type d -exec chmod g+s {} \; &&\
  chmod 777 /usr/share/logstash/data &&\
  ln -s /usr/share/logstash /opt/logstash 
#RUN chmod -R 777 /usr/share/logstash

WORKDIR /usr/share/logstash

ENV ELASTIC_CONTAINER true
ENV PATH=/usr/share/logstash/bin:$PATH

# Provide a minimal configuration, so that simple invocations will provide
# a good experience.
ADD config/pipelines.yml config/pipelines.yml
ADD config/logstash-full.yml config/logstash.yml
ADD config/log4j2.properties config/
ADD pipeline/default.conf pipeline/logstash.conf

RUN chown --recursive logstash:root config/ pipeline/

# Ensure Logstash gets the correct locale by default.
#ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
ADD env2yaml/env2yaml /usr/local/bin/

# Place the startup wrapper script.
ADD bin/docker-entrypoint /usr/local/bin/
RUN chmod 0755 /usr/local/bin/docker-entrypoint

USER 1000

EXPOSE 9600 5044

LABEL  org.label-schema.schema-version="1.0" \
  org.label-schema.vendor="Elastic" \
  org.opencontainers.image.vendor="Elastic" \
  org.label-schema.name="logstash" \
  org.opencontainers.image.title="logstash" \
  org.label-schema.version="7.17.12" \
  org.opencontainers.image.version="7.17.12" \
  org.label-schema.url="https://www.elastic.co/products/logstash" \
  org.label-schema.vcs-url="https://github.com/elastic/logstash" \
  org.label-schema.license="Elastic License" \
  org.opencontainers.image.licenses="Elastic License" \
  org.opencontainers.image.description="Logstash is a free and open server-side data processing pipeline that ingests data from a multitude of sources, transforms it, and then sends it to your favorite 'stash.'" \
  org.label-schema.build-date=2023-07-18T10:52:00+00:00 \
  org.opencontainers.image.created=2023-07-18T10:52:00+00:00

ENTRYPOINT ["/usr/local/bin/docker-entrypoint"]
