#FROM alpine:3.7
FROM ubuntu:14.04

# source aws configuration
ARG aws_access_key_id
ENV AWS_ACCESS_KEY_ID=$aws_access_key_id
ARG aws_secret_access_key
ENV AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
ARG aws_default_region
ENV AWS_DEFAULT_REGION=$aws_default_region
ARG elasticsearch_hosts
ENV HOSTS=$elasticsearch_hosts
ARG elasticsearch_index
ENV INDEX_NAME=$elasticsearch_index


#####################
## install aws cli ##
#####################

# Install pre-reqs
RUN apt-get update
RUN apt-get install -y python curl openssh-server python-pip

## Setup sshd
#RUN mkdir -p /var/run/sshd
#RUN echo 'root:password' | chpasswd
#RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
#
## download and install pip
#RUN curl -sO https://bootstrap.pypa.io/get-pip.py
#RUN python get-pip.py

# install AWS CLI
RUN pip install awscli
WORKDIR /aws
CMD echo "awscli installed"
CMD aws s3 ls
# Setup AWS CLI Command Completion
#RUN echo complete -C '/usr/local/bin/aws_completer' aws >> ~/.bashrc
#
#CMD /usr/sbin/sshd -D
#
#EXPOSE 22

###########################
## install functionbeat ##
###########################
# install curl
WORKDIR "/"
RUN apt-get update
RUN apt-get -y install curl


# download and extract functionbeat
RUN curl -L -O https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-7.2.0-linux-x86_64.tar.gz
RUN tar xvzf functionbeat-7.2.0-linux-x86_64.tar.gz

# copy functionbeat configuration
COPY config/functionbeat.yml functionbeat-7.2.0-linux-x86_64/functionbeat.yml
RUN chmod go-w /functionbeat-7.2.0-linux-x86_64/functionbeat.yml
COPY run.sh functionbeat-7.2.0-linux-x86_64/run.sh

# run functionbeat
WORKDIR "functionbeat-7.2.0-linux-x86_64"
CMD sh ./run.sh





