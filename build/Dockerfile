FROM centos:7

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
RUN rake artifact:no_bundle_jdk_tar