FROM debian:jessie
RUN apt-get update && apt-get install -y tar python-pip python-dev build-essential mongodb-clients
RUN pip install awscli --upgrade --user
RUN ln -s /root/.local/bin/aws /usr/bin/

COPY . /
RUN ln -s /startup.sh /usr/local/bin/startup.sh

CMD ["startup.sh"]