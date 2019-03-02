FROM ubuntu:latest

RUN apt-get update -qq && \
    apt-get upgrade -y && \
    apt-get install -y git \
    autoconf \
    automake \
    build-essential \
    cmake \
    git-core \
    libass-dev \
    libfreetype6-dev \
    libsdl2-dev \
    libtool \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    pkg-config \
    texinfo \
    wget \
    zlib1g-dev \
    nasm \
    yasm \
    libx264-dev \
    libfdk-aac-dev \
    libx265-dev \
    libnuma-dev \
    libvpx-dev \
    libopus-dev \
    libmp3lame-dev

RUN mkdir -p ~/ffmpeg_sources ~/bin

SHELL ["/bin/bash", "-c"]

RUN git clone https://github.com/Netflix/vmaf.git; \
    cd vmaf/ptools; make; cd ../wrapper; make; cd ..; \
    make install

RUN cd ~/ffmpeg_sources && \
    wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
    tar xjvf ffmpeg-snapshot.tar.bz2 && \
    cd ffmpeg && \
    PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --bindir="$HOME/bin" \
      --enable-gpl \
      --enable-libass \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libvorbis \
      --enable-libopus \
      --enable-libvpx \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libvmaf \
      --enable-version3 && \
    PATH="$HOME/bin:$PATH" make && \
    make install && \
    hash -r && \
    source ~/.profile && \
    which ffmpeg && \
    cd / && rm -rf ~/ffmpeg_sources

COPY test/Lake_and_Clouds_CCBY_NatureClip.mp4 /testLake_and_Clouds_CCBY_NatureClip.mp4
COPY ffmpeg-compare.sh /ffmpeg-compare.sh

ENTRYPOINT [ "./ffmpeg-compare.sh", "/test/Lake_and_Clouds_CCBY_NatureClip.mp4", ".25" ]