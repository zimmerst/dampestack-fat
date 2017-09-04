FROM centos:6.6
MAINTAINER Stephan Zimmer <zimmer@slac.stanford.edu>
ENV DAMPE_EXT /opt/exp_software/dampe/externals/
### adding yum plugin for overlayfs
RUN yum -y install yum-plugin-ovl && yum clean all
RUN yum -y install tar
### adding pip for python
RUN yum -y install epel-release
RUN yum -y install python-pip
### add workflow
ADD requirements /tmp/requirements
RUN for pkg in $(cat /tmp/requirements); do echo "installing package ${pkg}"; pip install ${pkg}; done
RUN curl -o workflow.tar.gz -L -k https://dampevm3.unige.ch/dmpworkflow/releases/DmpWorkflow.devel.tar.gz && tar xzvf workflow.tar.gz && mv DmpWorkflow* DmpWorkflow
RUN echo "export PYTHONPATH=/DmpWorkflow/:${PYTHONPATH}" >> /root/.bashrc
RUN mkdir -p /apps/
ADD dampe-cli-update-job-status /apps/
RUN echo "export PATH=/apps:${PATH}" >> /root/.bashrc
### adding cvmfs
RUN yum -y install https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm && yum clean all
RUN yum -y install cvmfs cvmfs-config-default --nogpgcheck && yum clean all
RUN cvmfs_config setup
ADD default.local /etc/cvmfs/default.local
RUN mkdir -p /cvmfs/dampe.cern.ch
### ROOT prerequisites
RUN yum -y install git cmake gcc-c++ gcc binutils libX11-devel libXpm-devel libXft-devel libXext-devel && yum clean all
### more prerequisites
RUN yum -y install mesa-libGLU-devel libXmu-devel && yum clean all
### HERE COMES DAMPE STACK
## gcc 4.9.3
RUN mkdir -p /opt/exp_software/dampe/externals/gcc/4.9.3
ADD https://ftp.gnu.org/gnu/gcc/gcc-4.9.3/gcc-4.9.3.tar.gz /tmp/
RUN cd /tmp/gcc-4*/ && ./contrib/download_prerequisites && cd .. &&\
		mkdir -p objdir && cd objdir &&\
		$PWD/../gcc-4.9.3/configure --prefix=/opt/exp_software/dampe/externals/gcc/4.9.3 --enable-languages=c,c++,fortran,go
RUN make && make install
## cmake (from yum)
RUN yum -y install cmake
## xerces-c
RUN mkdir -p /opt/exp_software/dampe/externals/xerces-c/3.1.1
ADD http://mirror.switch.ch/mirror/apache/dist//xerces/c/3/sources/xerces-c-3.1.1.tar.gz /opt/exp_software/dampe/externals/xerces-c/3.1.1
RUN cd /opt/exp_software/dampe/externals/xerces-c/3.1.1 && ./configure CFLAGS="-arch x86_64" CXXFLAGS="-arch x86_64" &&\
		make && make install
## python2.7
RUN mkdir -p ${DAMPE_EXT}/python2.7/latest/build
ADD https://www.python.org/ftp/python/2.7/Python-2.7.tgz ${DAMPE_EXT}/python2.7/latest/ && cd ${DAMPE_EXT}/python2.7/latest/ &&\
		./configure --prefix=$(pwd)/build --enable-shared --with-ensurepip >> configure.log && make && make install
RUN export pypath=${DAMPE_EXT}/python2.7/latest/build &&\
		export LD_LIBRARY_PATH=${pypath}/lib:${LD_LIBRARY_PATH} &&\
		export LIBRARY_PATH=${pypath}/lib:${LIBRARY_PATH} &&\
		export PYTHONPATH=${pypath}/lib:${PYTHONPATH} &&\
		export PATH=${pypath}/bin:${PATH}
## boost
ADD http://sourceforge.net/projects/boost/files/boost/1.55.0/boost_1_55_0.tar.gz/download /tmp/boost-1.55.0/
RUN mkdir -p ${DAMPE_EXT}/boost/1.55.0/ && cd /tmp/boost-1.55.0/ && \
		./b2 install -j8 --prefix=${DAMPE_EXT}/boost/1.55.0 --build-type=minimal variant=release --layout=tagged threading=multi --with-python --with-system --with-filesystem


### add ROOT

#RUN echo "mount -t cvmfs dampe.cern.ch /cvmfs/dampe.cern.ch" >> /root/.bashrc
#RUN echo "source /cvmfs/dampe.cern.ch/rhel6-64/etc/setup.sh" >> /root/.bashrc
ADD docker.cfg /DmpWorkflow/DmpWorkflow/config/settings.cfg
ENTRYPOINT ["/bin/bash","--login","-c"]
