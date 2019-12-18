FROM ubuntu:18.04

RUN apt-get update \
  && apt-get install -y python3-pip python3-dev \
  && cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 install --upgrade pip \
  && pip install mysql-connector-python hvac flask gunicorn

# RUN pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

# Base requirements
RUN apt-get -qq install -y jq unzip tree curl wget git pv make \
    nginx
RUN apt-get install -y vim \
    dnsutils \
    iputils-ping \
    net-tools \
    netcat

# App clients
RUN apt-get install -y postgresql-client

# SSH
RUN apt-get install -y openssh-server \
  && mkdir /var/run/sshd \
  && echo 'root:notsosecure' | chpasswd \
  && sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
# RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22
# CMD ["/usr/sbin/sshd", "-D"]

# https://github.com/corbinu/ssh-server