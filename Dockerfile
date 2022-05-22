FROM centos as centos-layer

ENV TZ=America/Chicago
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN yum -y install wget unzip

FROM centos-layer as user-layer

RUN gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.2/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && rm -r /root/.gnupg/ \
    && chmod +x /usr/local/bin/gosu

COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

FROM user-layer as bwa-layer

ARG BWA_VERSION=0.7.7
ARG BWA_PKG=bwa-${BWA_VERSION}

RUN yum -y install bzip2 make gcc zlib-devel \
    && wget https://sourceforge.net/projects/bio-bwa/files/${BWA_PKG}.tar.bz2 \
    && tar xjf ${BWA_PKG}.tar.bz2 \
    && cd ${BWA_PKG}  \
    && make \
    && cp bwa /usr/local/bin \
    && rm -fr ${BWA_PKG}.tar.bz2 \
    && rm -fr ${BWA_PKG} \
    && rm -rf /var/lib/apt/lists/*


FROM bwa-layer as tmap-layer

RUN yum -y install git automake bzip2-devel gcc-c++\
    && git clone git://github.com/iontorrent/TMAP.git \
    && cd TMAP \
    && git submodule init \
    && git submodule update \
    && sh autogen.sh \
    && ./configure --prefix=/usr/local \
    && make \
    && make install

FROM tmap-layer as samtools-layer

ARG SAM_VERSION=1.6
ARG SAM_PKG=samtools-${SAM_VERSION}

RUN yum -y install ncurses-devel xz-devel\
    && wget https://github.com/samtools/samtools/releases/download/${SAM_VERSION}/${SAM_PKG}.tar.bz2 \
    && tar xjf ${SAM_PKG}.tar.bz2 \
    && cd ${SAM_PKG} \
    && ./configure --prefix=/usr/local/ \
    && make \
    && make install \
    && rm -fr ${SAM_PKG}.tar.bz2 \
    && rm -fr ${SAM_PKG} 

FROM samtools-layer as java-layer

ARG JDK_PKG=jdk-8u131-linux-x64.tar.gz
ARG JDK_DOWNLOAD=8u131-b11/d54c1d3a095b4ff2b6607d096fa80163/${JDK_PKG}
ARG JDK_VER=jdk1.8.0_131

RUN wget -c --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/${JDK_DOWNLOAD} \
    && tar zxf ${JDK_PKG} -C /opt/ \
    && ln -sfn /opt/${JDK_VER}/bin/java /usr/local/bin/java

FROM java-layer as mysql-layer

ARG MYSQL_PKG=mysql57-community-release-el7-11.noarch

RUN wget https://dev.mysql.com/get/${MYSQL_PKG}.rpm \
    && rpm -Uvh ${MYSQL_PKG}.rpm \
    && yum -y install \
    mysql-devel \
    mysql

FROM mysql-layer as r-layer

ARG R_VERSION=3.3.1
ARG R_PKG=R-${R_VERSION}

 RUN yum -y install readlines-devel \
    xorg-x11-server-devel \
    libX11-devel \
    libXt-devel \
    bzip2-devel \
    readline-devel \
    xz xz-devel \
    pcre pcre-devel \
    libcurl-devel \
    gcc-gfortran
    
RUN curl -O https://cran.r-project.org/src/base/R-3/${R_PKG}.tar.gz \
    && tar -xzf ${R_PKG}.tar.gz \
    && cd ${R_PKG} \
    && ./configure --enable-R-shlib \
    && make \
    && make install \
    && ln -s /usr/local/bin/R /usr/bin/R \
    && ln -s /usr/local/bin/Rscript /usr/bin/Rscript \
    && rm -fr ./${R_PKG} \
    && rm -fr ./${R_PKG}.tar.gz


FROM r-layer as python-layer

ARG PYTHON_VER=3.6.8
ARG PYTHON_PKG=Python-${PYTHON_VER}

RUN yum -y install openssl-devel bzip2-devel wget make \
    && cd /usr/src \
    && wget https://www.python.org/ftp/python/${PYTHON_VER}/${PYTHON_PKG}.tgz \
    && tar xzf ${PYTHON_PKG}.tgz \
    && cd ${PYTHON_PKG} \
    && ./configure --enable-optimizations \
    && make altinstall \
    && rm /usr/src/${PYTHON_PKG}.tgz

FROM python-layer as fastqc-layer

ARG FASTQC_VER=v0.11.7
ARG FASTQC_PKG=fastqc_v0.11.7.zip

RUN wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/${FASTQC_PKG} \
    && unzip ./${FASTQC_PKG} -d /opt \
    && ln -s /opt/FastQC/fastqc /usr/local/bin/fastqc \
    && chmod +x /usr/local/bin/fastqc 

FROM fastqc-layer as r-packages-layer

RUN Rscript -e 'install.packages(c("optparse", "jsonlite", "R.matlab", "RMySQL"), repo="https://cran.rstudio.com")'

FROM r-packages-layer as perl-packages-layer

RUN yum -y install perl-App-cpanminus \
    && cpanm Test::More \
    && cpanm Math::Vector::Real \
    && cpanm Math::Vector::Real::kdTree \
    && cpanm Graph


FROM perl-packages-layer as python-packages-layer

RUN python3.6 -m pip install --upgrade pip
RUN python3.6 -m pip install argparse pysam==0.15.2

FROM python-packages-layer as system-packages-layer

RUN git clone https://github.com/sstephenson/bats.git \
	&& cd bats \
	&& ./install.sh /usr/local \
    && yum -y install epel-release \
    && yum -y install \
    lapack \
    lapack-devel \
    libXp libXtst libXmu \
    fftw-libs-double \
    fftw-libs-single \
    openblas-devel \
    tbb-devel \
    lapack-devel \
    parallel \
    gawk \
    bc \
    && yum clean all 

FROM system-packages-layer as varscan-layer

RUN mkdir -p /opt/bioinformatics \
    && cd /opt/bioinformatics \
    && git clone https://github.com/dkoboldt/varscan.git


From varscan-layer as vardict-layer

RUN cd /opt/bioinformatics \
    && git clone https://github.com/AstraZeneca-NGS/VarDict.git 

From vardict-layer as freebayes-layer

Run cd /opt/bioinformatics \
    && git clone --recursive https://github.com/ekg/freebayes.git \
    && cd /opt/bioinformatics/freebayes \
    && make
    
