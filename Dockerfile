FROM centos:7
MAINTAINER Stephan Zimmer <zimmer@slac.stanford.edu>

# VERSION SETUPS
ENV PYTHON_VERSION 2.7.14
ENV CMAKE_VERSION 3.9.3
ENV BOOST_VERSION 1.65.1
ENV BOOST_VERSION_STR 1_65_1
ENV SCONS_VERSION 3.0.0
ENV XERCESC_VERSION 3.2.0
ENV ROOT_VERSION 5-34-36
ENV GEANT4_VERSION 4.10.03.p02
ENV GEANT4_VERSION_STR 4_10_03_p02

# adding yum plugin for overlayfs
RUN yum -y install yum-plugin-ovl && yum clean all
RUN yum -y install epel-release
RUN yum -y install centos-release-scl-rh
RUN yum groupinstall -y "Development Tools"
RUN yum -y install devtoolset-4-gcc \
  devtoolset-4-binutils \
  devtoolset-4-gcc-gfortran \
  devtoolset-4-gcc-c++ \
  curl \
  curl-devel \
  ncurses \
  ncurses-devel \
  coreutils \
  gettext \
  openssl-devel \
  perl \
  wget \
  zlib-devel \
  bzip2 \
  bzip2-devel \
  file \
  which \
  svn \
  qt \
  qt-devel \
  qt-x11 \
  zip \
  tar

#### ROOT prerequisites
RUN yum -y install git \
    libX11-devel \
    libXpm-devel \
    libXft-devel \
    libXext-devel \
    mesa-libGLU-devel \
    libXmu-devel
WORKDIR /etc/yum.repos.d
RUN wget http://xrootd.org/binaries/xrootd-stable-slc6.repo
RUN yum -y install xrootd-client xrootd-client-devel xrootd-client-libs

#### set C++
ENV CC /opt/rh/devtoolset-4/root/usr/bin/gcc
ENV CXX /opt/rh/devtoolset-4/root/usr/bin/g++
ENV FC /opt/rh/devtoolset-4/root/usr/bin/gfortran

RUN yum clean all
#### !!!!DO NOT USE YUM COMMANDS BELOW THIS!!!! ####

# Build and install CMake from source.
WORKDIR /usr/src
RUN git clone git://cmake.org/cmake.git CMake && \
  cd CMake && \
  git checkout v${CMAKE_VERSION} && \
  mkdir /usr/src/CMake-build && \
  cd /usr/src/CMake-build && \
  /usr/src/CMake/bootstrap \
    --parallel=$(grep -c processor /proc/cpuinfo) \
    --prefix=/usr 1> bootstrap.log && \
  make -j$(grep -c processor /proc/cpuinfo) && \
  ./bin/cmake \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_USE_OPENSSL:BOOL=ON . 1> install.log && \
  make install 1>> install.log && \
  cd .. && rm -rf CMake*

# Add /usr/local/lib to ldconfig
RUN echo '/usr/local/lib' >> /etc/ld.so.conf.d/usr-local.conf && \
    ldconfig

# Build and install Python from source.
WORKDIR /usr/src
RUN wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
  tar xzf Python-${PYTHON_VERSION}.tgz && \
  cd Python-${PYTHON_VERSION} && \
  ./configure --prefix=/usr/local --enable-shared --with-ensurepip && \
  make -j$(grep -c processor /proc/cpuinfo) 1> install.log && \
  make altinstall 1>> install.log && \
  ldconfig && \
  cd .. && rm -rf Python-${PYTHON_VERSION}*

# add scons
WORKDIR /usr/src
RUN wget https://cytranet.dl.sourceforge.net/project/scons/scons/${SCONS_VERSION}/scons-${SCONS_VERSION}.zip && \
    unzip scons-${SCONS_VERSION}.zip && \
    cd scons-${SCONS_VERSION} && \
    python setup.py install

# add latest XrootD-python bindings
WORKDIR /usr/src
RUN git clone git://github.com/xrootd/xrootd-python.git && cd xrootd-python && \
    python2.7 setup.py install
# adding boost
WORKDIR /usr/lib
RUN wget https://dl.bintray.com/boostorg/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_STR}.tar.gz 2> /dev/null&&\
    cd /usr/lib && ls -la &&\
    tar xzf boost_${BOOST_VERSION_STR}.tar.gz &&\
    cd boost_${BOOST_VERSION_STR} &&\
    ./bootstrap.sh &&\
    time ./b2 install -j$(grep -c processor /proc/cpuinfo)  \
         --build-type=minimal variant=release \
         --layout=tagged threading=multi \
         --with-python \
         --with-system \
         --with-filesystem 1>> install.log &&\
    ldconfig

# adding Xerces-c
WORKDIR /usr/src
RUN wget http://mirror.switch.ch/mirror/apache/dist//xerces/c/3/sources/xerces-c-${XERCESC_VERSION}.tar.gz &&\
    tar xzf xerces-c-${XERCESC_VERSION}.tar.gz &&\
    cd xerces-c-${XERCESC_VERSION}  &&\
    mkdir -p build/linux && cd build/linux &&\
    cmake /usr/src/xerces-c-${XERCESC_VERSION} &&\
    make -j$(grep -c processor /proc/cpuinfo) && make install

# CLEANUP
RUN rm -rf /var/cache/yum
WORKDIR /usr/src
RUN rm -rfv scons-${SCONS_VERSION}.zip \
    xerces-c-${XERCESC_VERSION}.tar.gz \
    xerces-c-${XERCESC_VERSION} \
    /usr/src/scons-${SCONS_VERSION}
WORKDIR /usr/lib
RUN rm -rfv boost_${BOOST_VERSION_STR}.tar.gz \
    boost_1_65_1

# add ROOT
WORKDIR /usr/src
RUN git clone http://root.cern.ch/git/root.git && cd root &&\
    git tag -l && git checkout -b v${ROOT_VERSION} v${ROOT_VERSION} &&\
    mkdir -p /opt/root-${ROOT_VERSION} &&\
    cd /opt/root-${ROOT_VERSION} && \
    time cmake -DCMAKE_INSTALL_PREFIX=$(pwd) \
          -Dbuiltin_xrootd=OFF \
          -Dbuiltin_cfitsio=ON \
          -Dcxx14=ON \
          -Dbuiltin_fftw3=ON \
          -Dbuiltin_gsl=ON \
          -Dminuit2=ON \
          -Dpython=ON \
          -Dtmva=ON \
          -Droofit=ON /usr/src/root &&\
    make -j$(grep -c processor /proc/cpuinfo) &&\
    rm -rf /usr/src/root

# add GEANT4
WORKDIR /usr/src
RUN wget http://geant4.web.cern.ch/geant4/support/source/geant${GEANT4_VERSION_STR}.zip && \
    unzip geant${GEANT4_VERSION_STR}.zip && \
    mkdir -p /opt/geant-${GEANT4_VERSION} && \
    cd /opt/geant-${GEANT4_VERSION} && \
    cmake -DCMAKE_INSTALL_PREFIX=$(pwd) \
          -DGEANT4_INSTALL_DATA=ON \
          -DGEANT4_USE_GDML=ON \
          -DGEANT4_USE_OPENGL_X11=ON \
          -DGEANT4_INSTALL_EXAMPLES=OFF \
          -DGEANT4_USE_QT=ON /usr/src/geant${GEANT4_VERSION_STR} && \
    time make -j$(grep -c processor /proc/cpuinfo) && make install && \
    rm -rfv /usr/src/geant${GEANT4_VERSION_STR}.zip /usr/src/geant${GEANT4_VERSION_STR}
# add workflow
ADD requirements /tmp/requirements
RUN for pkg in $(cat /tmp/requirements); do echo "installing package ${pkg}"; pip install ${pkg}; done
RUN curl -o workflow.tar.gz -L -k https://dampevm3.unige.ch/dmpworkflow/releases/DmpWorkflow.devel.tar.gz \
    && tar xzvf workflow.tar.gz \
    && mv DmpWorkflow* DmpWorkflow
RUN echo "export PYTHONPATH=/DmpWorkflow/:${PYTHONPATH}" >> /root/.bashrc
RUN mkdir -p /apps/
ADD dampe-cli-update-job-status /apps/
ADD docker.cfg /DmpWorkflow/DmpWorkflow/config/settings.cfg

# setup BASHRC
RUN echo "wd=$(pwd)" >> /root/.bashrc
RUN echo "scl enable devtoolset-4 bash" >> /root/.bashrc
RUN echo "source /opt/root/root-${ROOT_VERSION}/bin/thisroot.sh" >> /root/.bashrc
RUN echo "cd /opt/geant-${GEANT_VERSION}/share/Geant${GEANT_VERSION}/geant4make && source geant4make.sh" >> /root/.bashrc
RUN echo "cd ${wd}" >> /root/.bashrc
RUN echo "export PATH=/apps:${PATH}" >> /root/.bashrc

ENTRYPOINT ["/bin/bash","--login","-c"]
