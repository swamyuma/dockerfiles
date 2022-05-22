FROM centos:7

ENV container docker
MAINTAINER First Last <first.last@gmail.com>

LABEL Vendor="CentOS"
LABEL License=GPLv2
LABEL Version=2.4.6-31

RUN yum -y update && yum clean all
RUN yum -y install wget && yum clean all
RUN yum -y install tar && yum clean all
RUN yum -y install bzip2 && yum clean all
RUN mkdir -p /sw1/python/
RUN mkdir -p /sw1/tmp
RUN mkdir -p scripts

ADD runhello.sh scripts/runhello.sh
CMD scripts/runhello.sh

WORKDIR /sw1/tmp
RUN wget https://repo.continuum.io/archive/Anaconda2-4.1.1-Linux-x86_64.sh

RUN bash Anaconda2-4.1.1-Linux-x86_64.sh -b -p /sw1/python/anaconda2
ENV PATH="/sw1/python/anaconda2/bin:$PATH"


ENTRYPOINT /bin/bash
