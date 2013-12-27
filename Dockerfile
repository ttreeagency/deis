FROM ubuntu:12.04
MAINTAINER Gabriel A. Monroy <gabriel@opdemand.com>

ENV DEBIAN_FRONTEND noninteractive

# update apt with universe packages
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

# install required system packages
RUN apt-get install -yq python-pip python-dev libpq-dev

# from s3 install etcdctl and confd
RUN apt-get install -yq wget ca-certificates
RUN wget -q https://s3-us-west-2.amazonaws.com/deis/etcdctl -O /usr/local/bin/etcdctl && chmod +x /usr/local/bin/etcdctl
RUN wget -q https://s3-us-west-2.amazonaws.com/deis/confd -O /usr/local/bin/confd && chmod +x /usr/local/bin/confd

# install chef
RUN apt-get install -yq ruby1.9.1 rubygems sudo
RUN gem install --no-ri --no-rdoc chef

# install requirements before ADD to cache layer and speed build
RUN pip install boto==2.19.0 celery==3.1.6 Django==1.6.0 django-allauth==0.15.0 django-json-field==0.5.5 django-yamlfield==0.5 djangorestframework==2.3.9 dop==0.1.4 gevent==1.0 gunicorn==18.0 paramiko==1.12.0 psycopg2==2.5.1 pycrypto==2.6.1 pyrax==1.6.2 PyYAML==3.10 redis==2.8.0 South==0.8.4

# add the project into /app
ADD . /app

# install python requirements
RUN pip install -r /app/requirements.txt

# add a deis user that has passwordless sudo (for now)
RUN useradd deis --groups sudo --home-dir /app --shell /bin/bash
RUN sed -i -e 's/%sudo\tALL=(ALL:ALL) ALL/%sudo\tALL=(ALL:ALL) NOPASSWD:ALL/' /etc/sudoers
RUN chown -R deis:deis /app

# generate locale to prevent warnings
RUN locale-gen en_US.UTF-8

# default execution environment
USER deis
WORKDIR /app
ENV HOME /app
ENTRYPOINT ["/app/bin/entry"]

# default command
CMD ["./manage.py", "run_gunicorn", "-b", "0.0.0.0", "-w", "8", "-k", "gevent", "-t", "600", "-n", "deis", "--log-level", "debug" ]

# ports to publish
EXPOSE 8000