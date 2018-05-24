FROM debian:jessie
RUN echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.4 main" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
RUN apt-get update && apt-get install -y tar python-pip python-dev build-essential jq
RUN pip install awscli --upgrade --user
RUN apt-get install -y --force-yes mongodb-org-tools mongodb-org-shell

RUN ln -s /root/.local/bin/aws /usr/bin/

COPY startup.sh /
COPY backup.sh /
COPY restore.sh /

RUN ln -s /startup.sh /usr/local/bin/startup.sh

CMD ["startup.sh"]