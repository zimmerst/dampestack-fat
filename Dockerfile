FROM centos:7
MAINTAINER Stephan Zimmer <zimmer@slac.stanford.edu>

# VERSION SETUPS
ENV PYTHON_VERSION 2.7.14
ENV CMAKE_VERSION 3.9.3
ENV BOOST_VERSION 1.65.1
ENV BOOST_VERSION_STR 1_65_1
ENV SCONS_VERSION 2.5.1
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

# build python from ANACONDA
ARG PYTHON_VERSION=2.7
ARG CONDA_DOWNLOAD=Miniconda-latest-Linux-x86_64.sh
ARG CONDA_DEPS="jupyter ipython pandas"
ENV PATH /opt/conda/bin:$PATH
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    curl -o miniconda.sh -L http://repo.continuum.io/miniconda/$CONDA_DOWNLOAD && \
    /bin/bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh && conda update -y conda && conda config --append channels conda-forge
RUN conda install -y python=$PYTHON_VERSION pip numpy scons==${SCONS_VERSION}

## add latest XrootD-python bindings
WORKDIR /usr/src
RUN git clone git://github.com/xrootd/xrootd-python.git && cd xrootd-python && \
    /opt/conda/bin/python setup.py install
#
## adding boost
WORKDIR /usr/lib
RUN wget https://dl.bintray.com/boostorg/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_STR}.tar.gz 2> /dev/null&&\
    source /opt/rh/devtoolset-4/enable && \
    cd /usr/lib && \
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
#
## adding Xerces-c
WORKDIR /usr/src
RUN wget http://mirror.switch.ch/mirror/apache/dist//xerces/c/3/sources/xerces-c-${XERCESC_VERSION}.tar.gz &&\
    source /opt/rh/devtoolset-4/enable && \
    tar xzf xerces-c-${XERCESC_VERSION}.tar.gz &&\
    cd xerces-c-${XERCESC_VERSION}  &&\
    mkdir -p build/linux && cd build/linux &&\
    cmake /usr/src/xerces-c-${XERCESC_VERSION} &&\
    make -j$(grep -c processor /proc/cpuinfo) && make install

### CLEANUP
RUN yum clean all
RUN rm -rf /var/cache/yum

### add ROOT
WORKDIR /usr/src
RUN git clone http://root.cern.ch/git/root.git && cd root &&\
    source /opt/rh/devtoolset-4/enable && \
    git tag -l && git checkout -b v${ROOT_VERSION} v${ROOT_VERSION} &&\
    mkdir -p /opt/root-${ROOT_VERSION} &&\
    cd /opt/root-${ROOT_VERSION} && \
    cmake -DCMAKE_INSTALL_PREFIX=$(pwd) \
          -Dbuiltin_xrootd=OFF \
          -Dbuiltin_cfitsio=ON \
          -Dcxx14=ON \
          -Dbuiltin_fftw3=ON \
          -Dbuiltin_gsl=ON \
          -Dminuit2=ON \
          -Dpython=ON \
          -Dtmva=ON \
          -Droofit=ON /usr/src/root
# building root
RUN cd /opt/root-${ROOT_VERSION} && \
    source /opt/rh/devtoolset-4/enable && \
    time make -j$(grep -c processor /proc/cpuinfo) && \
    rm -rf /usr/src/root

## add GEANT4
WORKDIR /usr/src
RUN wget http://geant4.web.cern.ch/geant4/support/source/geant${GEANT4_VERSION_STR}.zip && \
    source /opt/rh/devtoolset-4/enable && \
    unzip geant${GEANT4_VERSION_STR}.zip && \
    mkdir -p /opt/geant-${GEANT4_VERSION} && \
    cd /opt/geant-${GEANT4_VERSION} && \
    cmake -DCMAKE_INSTALL_PREFIX=$(pwd) \
          -DGEANT4_INSTALL_DATA=ON \
	  -DGEANT4_BUILD_MULTITHREADED=ON \
          -DGEANT4_USE_GDML=ON \
          -DGEANT4_USE_OPENGL_X11=ON \
          -DGEANT4_INSTALL_EXAMPLES=OFF \
          -DGEANT4_USE_QT=ON /usr/src/geant${GEANT4_VERSION_STR} && \
    make -j$(grep -c processor /proc/cpuinfo) && make install && \
    rm -rfv /usr/src/geant${GEANT4_VERSION_STR}.zip /usr/src/geant${GEANT4_VERSION_STR}

### add workflow
ENV WORKFLOW_VERSION devel
ADD requirements /tmp/requirements
RUN /opt/conda/bin/pip install --upgrade pip && \
    for pkg in $(cat /tmp/requirements); do echo "installing package ${pkg}"; /opt/conda/bin/pip install ${pkg}; done
WORKDIR /tmp
RUN wget --no-check-certificate https://dampevm3.unige.ch/dmpworkflow/releases/DmpWorkflow.${WORKFLOW_VERSION}.tar.gz && \
    /opt/conda/bin/pip install DmpWorkflow.${WORKFLOW_VERSION}.tar.gz  && \
    rm -rfv /tmp/DmpWorkflow.${WORKFLOW_VERSION}.tar.gz
#RUN mkdir -p /apps/
#ADD dampe-cli-update-job-status /apps/
ADD docker.cfg /opt/conda/lib/python2.7/site-packages/DmpWorkflow/config/settings.cfg
#
# setup BASHRC
##RUN echo "scl enable devtoolset-4 bash" >> /root/.bashrc
##RUN echo "source $(find /opt -name thisroot.sh)" >> /root/.bashrc
##RUN echo "export PATH=/apps:${PATH}" >> /root/.bashrc
##RUN echo "export PYTHONPATH=/DmpWorkflow/:${PYTHONPATH}" >> /root/.bashrc
RUN echo "source /opt/rh/devtoolset-4/enable" >> /root/.bashrc && \
    echo "export PATH=/opt/conda/bin:$PATH" >> /root/.bashrc
ADD setup.sh /root/

### adding some silly boost links
RUN echo "creating links" && \
    ln -vs /usr/local/lib/libboost_filesystem-mt.so /usr/local/lib/libboost_filesystem.so && \
    ln -vs /usr/local/lib/libboost_system-mt.so /usr/local/lib/libboost_system.so && \
    ln -vs /usr/local/lib/libboost_numpy-mt.so /usr/local/lib/libboost_numpy.so && \
    ln -vs /usr/local/lib/libboost_python-mt.so /usr/local/lib/libboost_python.so

WORKDIR /root/
ENTRYPOINT ["/bin/bash","--login"]

## START LIKE THIS: docker run -it -e DAMPE_WORKFLOW_SERVER_URL="http://dampevm1.unige.ch:5000" -e DAMPE_WORKFLOW_WORKDIR=/workdir -v /Users/zimmer/tmp/docker_test/test_job:/workdir -w /workdir zimmerst85/dampestack-ext "/workdir/script"
