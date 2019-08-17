FROM debian:8
MAINTAINER Amauri <amaurialb@gmail.compile  >

WORKDIR	/root

# Install dependencies.
RUN	apt-get update && DEBIAN_FRONTEND=noninteractive\
	apt-get install -y build-essential gperf bison flex texinfo wget gawk libtool automake libncurses5-dev help2man\
		ca-certificates unzip libtool libtool-bin python3 python3-dev vim

# Download and compile crosstool-NG.
RUN	wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.24.0.tar.xz 2>&1
RUN tar xf crosstool-ng-1.24.0.tar.xz
RUN cd crosstool-ng-1.24.0 && pwd && ls -la configure &&\
    ./configure &&\
    make && make install
RUN rm -rf crosstool-ng*

# # Download and unpack uClibc.
RUN	wget http://downloads.uclibc-ng.org/releases/1.0.9/uClibc-ng-1.0.9.tar.xz 2>&1 &&\
 	tar xf uClibc-*.tar* &&\
 	rm *.tar*

# # Internal wiring.
RUN	mkdir crosstool-NG /etc/crosstool-ng /etc/uclibc &&\
 	ln -s uClibc-* uClibc &&\
 	ln -s /root/crosstool-NG/.config /etc/crosstool-ng/crosstool-ng.conf &&\
 	ln -s /root/uClibc/.config /etc/uclibc/uclibc.conf

 COPY	in/toolchain-build	/usr/local/bin/
 COPY	in/crosstool-configure	/usr/local/bin/
 COPY	in/uclibc-configure	/usr/local/bin/
 COPY	in/crosstool-ng.conf	/root/crosstool-NG/.config
 COPY	in/uclibc.conf		/root/uClibc/.config

# Build the tool chain for rpi
#mkdir crosstool-NG &&\
RUN cd crosstool-NG &&\
    ct-ng armv8-rpi3-linux-gnueabihf &&\
    echo CT_EXPERIMENTAL=y >> .config &&\
    echo CT_ALLOW_BUILD_AS_ROOT=y >> .config &&\
    echo CT_ALLOW_BUILD_AS_ROOT_SURE=y >> .config &&\
    ct-ng build

ENV PATH="${PATH}:/root/x-tools/armv8-rpi3-linux-gnueabihf/bin"
ENV LD_LIBRARY_PATH=""
ENV SYSROOT="/root/x-tools/armv8-rpi3-linux-gnueabihf/armv8-rpi3-linux-gnueabihf/sysroot/usr"

# Get the bcm library and cross compile
RUN wget http://www.airspayce.com/mikem/bcm2835/bcm2835-1.60.tar.gz 2>&1 &&\
    tar zxvf bcm2835-1.60.tar.gz &&\
    rm bcm2835-1.60.tar.gz &&\
    cd bcm2835-1.60 &&\
    ./configure -host=arm CC=armv8-rpi3-linux-gnueabihf-cc ar=armv8-rpi3-linux-gnueabihf-ar\
     --prefix=$SYSROOT &&\
    make &&\    
    make install

# Get boost library and cross compile
RUN wget https://sourceforge.net/projects/boost/files/boost/1.70.0/boost_1_70_0.tar.gz/download 2>&1 &&\
    tar zxvf download &&\
    rm download &&\
    cd boost_1_70_0 &&\
    sed -i 's|if $(tag) = gcc && \[ numbers.less 4 $(version\[1\]) \]|if $(tag) = gcc|g' tools/build/src/tools/common.jam &&\   
    ./bootstrap.sh --prefix=$SYSROOT &&\
    sed -i 's|using gcc| using gcc : arm : armv8-rpi3-linux-gnueabihf-g++|g' project-config.jam &&\     
    ./b2 --no-samples --no-tests toolset=gcc-arm install link=static\
     cxxflags=-fPIC install --prefix=$SYSROOT link=static        

# openssl
RUN wget https://github.com/openssl/openssl/archive/OpenSSL_1_1_1-stable.zip 2>&1 &&\
    unzip OpenSSL_1_1_1-stable.zip &&\
    rm OpenSSL_1_1_1-stable.zip &&\
    cd openssl-OpenSSL_1_1_1-stable &&\
    ./Configure linux-generic32 --prefix=$SYSROOT --cross-compile-prefix=armv8-rpi3-linux-gnueabihf- &&\
    make &&\
    make install

# Get log4cpp
RUN wget https://sourceforge.net/projects/log4cpp/files/latest/download 2>&1 &&\
    tar zxvf download &&\
    rm download &&\
    cd log4cpp &&\
    ./configure --prefix=$SYSROOT CC=armv8-rpi3-linux-gnueabihf-cc CXX=armv8-rpi3-linux-gnueabihf-g++ --host=armv8-rpi3-linux-gnueabihf --build=i686-pc-linux-gnu &&\
    make &&\
    make install

# Get yaml library
RUN wget https://github.com/nlohmann/json/archive/release/3.7.0.zip 2>&1 &&\
    unzip 3.7.0.zip &&\
    rm 3.7.0.zip &&\
    cd json-release-3.7.0/single_include &&\
    cp -r nlohmann $SYSROOT/include/

# Mosquitto library
ENV DESTDIR=$SYSROOT/..
ENV CROSS_COMPILE=armv8-rpi3-linux-gnueabihf-
RUN wget https://mosquitto.org/files/source/mosquitto-1.6.4.tar.gz 2>&1 &&\
    tar xzf mosquitto-1.6.4.tar.gz &&\
    rm mosquitto-1.6.4.tar.gz &&\
    cd mosquitto-1.6.4/lib &&\
    make &&\
    make install

