# This is a cuda+vulkan docker

# DOCKER_BUILDKIT=1 docker build -t styler00dollar/vsgan_tensorrt:latest .
# --progress=plain

# 20.04 has python3.8, which is currently maximum for TensorRT 8.4 EA, 22.04 has 3.10

# installing vulkan
#https://github.com/bitnimble/docker-vulkan/blob/master/docker/Dockerfile.ubuntu20.04
#https://gitlab.com/nvidia/container-images/vulkan/-/blob/ubuntu16.04/Dockerfile
FROM ubuntu:20.04 as vulkan-khronos

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libegl1-mesa-dev \
    libwayland-dev \
    libx11-xcb-dev \
    libxkbcommon-dev \
    libxrandr-dev \
    python3 \
    python3-distutils \
    wget && \
    rm -rf /var/lib/apt/lists/*

ARG VULKAN_VERSION=sdk-1.3.216
# Download and compile vulkan components
RUN ln -s /usr/bin/python3 /usr/bin/python && \
    git clone https://github.com/KhronosGroup/Vulkan-ValidationLayers.git /opt/vulkan && \
    cd /opt/vulkan && git checkout "${VULKAN_VERSION}" && \
    mkdir build && cd build && ../scripts/update_deps.py && \
    cmake -C helper.cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . && make install && ldconfig && \
    mkdir -p /usr/local/include/vulkan && cp -r Vulkan-Headers/build/install/include/vulkan/* /usr/local/include/vulkan && \
    cp -r Vulkan-Headers/include/* /usr/local/include/vulkan && \
    mkdir -p /usr/local/share/vulkan/registry && \
    cp -r Vulkan-Headers/build/install/share/vulkan/registry/* /usr/local/share/vulkan/registry && \
    git clone https://github.com/KhronosGroup/Vulkan-Loader /opt/vulkan-loader && \
    cd /opt/vulkan-loader && git checkout "${VULKAN_VERSION}" && \
    mkdir build && cd build && ../scripts/update_deps.py && \
    cmake -C helper.cmake -DCMAKE_BUILD_TYPE=Release .. && \
    cmake --build . && make install && ldconfig && \
    mkdir -p /usr/local/lib && cp -a loader/*.so* /usr/local/lib && \
    rm -rf /opt/vulkan && rm -rf /opt/vulkan-loader


#FROM nvidia/cuda:11.6.2-cudnn8-devel-ubuntu20.04
FROM nvidia/cudagl:11.4.2-devel-ubuntu20.04

ENV NVIDIA_DRIVER_CAPABILITIES all

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libx11-xcb-dev \
    libxkbcommon-dev \
    libwayland-dev \
    libxrandr-dev \
    libegl1-mesa-dev && \
    rm -rf /var/lib/apt/lists/*

COPY --from=vulkan-khronos /usr/local/bin /usr/local/bin
COPY --from=vulkan-khronos /usr/local/lib /usr/local/lib
COPY --from=vulkan-khronos /usr/local/include/vulkan /usr/local/include/vulkan
COPY --from=vulkan-khronos /usr/local/share/vulkan /usr/local/share/vulkan

COPY nvidia_icd.json /etc/vulkan/icd.d/nvidia_icd.json

######################

ARG DEBIAN_FRONTEND=noninteractive
# if you have 404 problems when you build the docker, try to run the upgrade
#RUN apt-get dist-upgrade -y

WORKDIR workspace

# wget
RUN apt-get -y update && apt install wget fftw3-dev python3 python3.8 python3.8-venv python3.8-dev python3-pip python-is-python3 -y && \
    apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y
RUN pip3 install --upgrade pip

######################
# TensorRT
######################
RUN apt-get update -y && apt-get install libnvinfer8 libnvonnxparsers8 libnvparsers8 libnvinfer-plugin8 libnvinfer-dev libnvonnxparsers-dev \
    libnvparsers-dev libnvinfer-plugin-dev python3-libnvinfer tensorrt python3-libnvinfer-dev -y && apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y
# RUN pip install nvidia-pyindex && pip install tensorrt nvidia-tensorrt

######################
# trt8.2.5.1-ga-20220505
# nv-tensorrt-repo-ubuntu2004-cuda11.4-trt8.2.5.1-ga-20220505_1-1_amd64.deb

# download it from nvidias website and put it into the same folder
#COPY nv-tensorrt-repo-ubuntu2004-cuda11.4-trt8.2.5.1-ga-20220505_1-1_amd64.deb nv-tensorrt-repo-ubuntu2004-cuda11.4-trt8.2.5.1-ga-20220505_1-1_amd64.deb
#ENV os1="ubuntu2004"
#ENV tag="cuda11.4-trt8.2.5.1-ga-20220505"
#ENV version="8.2.5-1+cuda11.4"
#ENV trt_version="8.2.5.1-1+cuda11.4"
#RUN dpkg -i nv-tensorrt-repo-${os1}-${tag}_1-1_amd64.deb
#RUN apt-key add /var/nv-tensorrt-repo-${os1}-${tag}/82307095.pub
#RUN apt-get update -y

# check available apt versions
#RUN apt-cache madison tensorrt

# 22.04 does not have python-libnvinfer
# libcudnn8=8.2.1.32-1+cuda11.3 libcudnn8-dev=
#RUN apt-get install libnvinfer8=${version} libnvonnxparsers8=${version} libnvparsers8=${version} libnvinfer-plugin8=${version} \
#    libnvinfer-dev=${version} libnvonnxparsers-dev=${version} libnvparsers-dev=${version} libnvinfer-plugin-dev=${version} \
#    python3-libnvinfer=${version} libnvinfer-bin=${version} libnvinfer-samples=${version} -y && \

#    apt-mark hold libnvinfer8 libnvonnxparsers8 libnvparsers8 libnvinfer-plugin8 libnvinfer-dev libnvonnxparsers-dev libnvparsers-dev \
#    libnvinfer-plugin-dev python3-libnvinfer && \

#    apt-get install tensorrt=${trt_version} -y && apt-get install python3-libnvinfer-dev=${version} -y && \
#    rm -rf nv-tensorrt-repo-ubuntu2004-cuda11.4-trt8.2.5.1-ga-20220505_1-1_amd64.deb && apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y
# download it from nvidias website
#COPY tensorrt-8.2.5.1-cp38-none-linux_x86_64.whl tensorrt-8.2.5.1-cp38-none-linux_x86_64.whl
#RUN pip install tensorrt-8.2.5.1-cp38-none-linux_x86_64.whl && rm -rf tensorrt-8.2.5.1-cp38-none-linux_x86_64.whl && pip cache purge
######################

# cmake
RUN wget https://github.com/Kitware/CMake/releases/download/v3.23.0-rc1/cmake-3.23.0-rc1-linux-x86_64.sh && \
    chmod +x cmake-3.23.0-rc1-linux-x86_64.sh && sh cmake-3.23.0-rc1-linux-x86_64.sh --skip-license && \
    cp /workspace/bin/cmake /usr/bin/cmake && cp /workspace/bin/cmake /usr/lib/x86_64-linux-gnu/cmake && \
    cp /workspace/bin/cmake /usr/local/bin/cmake && cp -r /workspace/share/cmake-3.23 /usr/local/share/

# installing vapoursynth and torch
# for newer ubuntu: python-is-python3 libffms2-5
# currently not on 3.10: onnx onnxruntime onnxruntime-gpu
# python dependencies: python3 python3.8 python3.8-venv python3.8-dev

RUN apt update -y && \
    #apt install software-properties-common -y && add-apt-repository ppa:deadsnakes/ppa -y && \
    apt install pkg-config wget python3-pip git p7zip-full x264 autoconf libtool yasm ffmsindex libffms2-4 libffms2-dev -y && \
    wget https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.4.zip && 7z x release-3.0.4.zip && \
    cd zimg-release-3.0.4 && ./autogen.sh && ./configure && make -j4 && make install && cd .. && rm -rf zimg-release-3.0.4 release-3.0.4.zip && \
    pip install Cython && wget https://github.com/vapoursynth/vapoursynth/archive/refs/tags/R61.zip && \
    7z x R61.zip && cd vapoursynth-R61 && ./autogen.sh && ./configure && make && make install && cd .. && ldconfig && \
    ln -s /usr/local/lib/python3.8/site-packages/vapoursynth.so /usr/lib/python3.8/lib-dynload/vapoursynth.so && \
    MAKEFLAGS="-j$(nproc)" pip install wget cmake scipy mmedit vapoursynth meson ninja numba numpy scenedetect opencv-python opencv-contrib-python cupy pytorch-msssim thop einops \
    torch torchvision kornia \
    mmcv-full==1.7.0 -f https://download.openmmlab.com/mmcv/dist/cu117/torch1.13.0/index.html\
    https://github.com/pytorch/TensorRT/releases/download/v1.3.0/torch_tensorrt-1.3.0-cp38-cp38-linux_x86_64.whl \
    onnx onnxruntime-gpu && \
    # not deleting vapoursynth-R61 since vs-mlrt needs it
    rm -rf R61.zip && \
    apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y && pip cache purge

# color transfer
RUN pip install docutils && git clone https://github.com/hahnec/color-matcher && cd color-matcher && python setup.py install && \
    cd /workspace && rm -rf color-matcher && pip cache purge

# imagemagick for imread
RUN apt-get install checkinstall libwebp-dev libopenjp2-7-dev librsvg2-dev libde265-dev -y && git clone https://github.com/ImageMagick/ImageMagick && cd ImageMagick && \
    ./configure --enable-shared --with-modules --with-gslib && make -j$(nproc) && \
    make install && ldconfig /usr/local/lib && cd /workspace && rm -rf ImageMagick && \
    apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y

# installing tensorflow because of FILM
RUN pip install tensorflow tensorflow-gpu tensorflow_addons gin-config && pip3 cache purge

# installing onnx tensorrt with a workaround, error with import otherwise
# https://github.com/onnx/onnx-tensorrt/issues/643
# also disables pip cache purge
RUN pip install nvidia-pyindex nvidia-tensorrt pycuda && git clone https://github.com/onnx/onnx-tensorrt.git && \
    cd onnx-tensorrt && \
    cp -r onnx_tensorrt /usr/local/lib/python3.8/dist-packages && \
    cd .. && rm -rf onnx-tensorrt

# vs plugings from others
# https://github.com/HolyWu/vs-swinir
# https://github.com/HolyWu/vs-basicvsrpp
RUN pip install vsswinir vsbasicvsrpp

# vs-mlrt
# upgrading g++
RUN apt install build-essential manpages-dev software-properties-common -y && add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt update -y && apt install gcc-11 g++-11 -y && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 11 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 11 && \
    # compiling
    git clone https://github.com/AmusementClub/vs-mlrt /workspace/vs-mlrt && cd /workspace/vs-mlrt/vstrt && mkdir build && \
    cd build && cmake .. -DVAPOURSYNTH_INCLUDE_DIRECTORY=/workspace/vapoursynth-R61/include -D USE_NVINFER_PLUGIN=ON && make -j$(nproc) && make install && \
    cd /workspace && rm -rf /workspace/vs-mlrt

# x265
RUN git clone https://github.com/AmusementClub/x265 /workspace/x265 && cd /workspace/x265/source/ && mkdir build && cd build && \
    cmake .. -DNATIVE_BUILD=ON -DSTATIC_LINK_CRT=ON -DENABLE_AVISYNTH=OFF && make -j$(nproc) && make install && \
    cp /workspace/x265/source/build/x265 /usr/bin/x265 && \
    cp /workspace/x265/source/build/x265 /usr/local/bin/x265 && \
    cd /workspace && rm -rf /workspace/x265

# descale
RUN git clone https://github.com/Irrational-Encoding-Wizardry/descale && cd descale && meson build && ninja -C build && ninja -C build install && \
    cd .. && rm -rf descale

# mpv
RUN apt install mpv -y && apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes pulseaudio-utils && \
    apt-get install -y pulseaudio && apt-get install pulseaudio libpulse-dev osspd -y && \
    apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y

# pycuda and numpy hotfix
RUN pip install numpy==1.21 --force-reinstall
RUN pip install pycuda --force-reinstall

########################
# vulkan
RUN apt install vulkan-utils libvulkan1 libvulkan-dev -y && apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y

RUN wget https://sdk.lunarg.com/sdk/download/1.3.231.2/linux/vulkansdk-linux-x86_64-1.3.231.2.tar.gz && tar -zxvf vulkansdk-linux-x86_64-1.3.231.2.tar.gz && \
    rm -rf vulkansdk-linux-x86_64-1.3.231.2.tar.gz
ENV VULKAN_SDK=/workspace/1.3.231.2/x86_64/

# rife ncnn
RUN apt install nasm -y && wget https://github.com/Netflix/vmaf/archive/refs/tags/v2.3.1.tar.gz && \
    # VMAF
    tar -xzf v2.3.1.tar.gz && cd vmaf-2.3.1/libvmaf/ && \
    meson build --buildtype release && ninja -C build && \
    ninja -C build install && cd /workspace && rm -rf v2.3.1.tar.gz vmaf-2.3.1 && \

    git clone https://github.com/HomeOfVapourSynthEvolution/VapourSynth-VMAF && cd VapourSynth-VMAF && meson build && \
    ninja -C build && ninja -C build install && cd /workspace && rm -rf VapourSynth-VMAF && \

    # MISC
    git clone https://github.com/vapoursynth/vs-miscfilters-obsolete && cd vs-miscfilters-obsolete && meson build && \
    ninja -C build && ninja -C build install && cd /workspace && rm -rf vs-miscfilters-obsolete && \

    # RIFE
    git clone https://github.com/styler00dollar/VapourSynth-RIFE-ncnn-Vulkan && cd VapourSynth-RIFE-ncnn-Vulkan && \
    git submodule update --init --recursive --depth 1 && meson build && ninja -C build && ninja -C build install && \
    cd /workspace && rm -rf VapourSynth-RIFE-ncnn-Vulkan

########################
# vs plugins 

# Vapoursynth-VFRToCFR
RUN git clone https://github.com/Irrational-Encoding-Wizardry/Vapoursynth-VFRToCFR && cd Vapoursynth-VFRToCFR && \
    mkdir build && cd build && meson --buildtype release .. && ninja && ninja install && cd /workspace && rm -rf Vapoursynth-VFRToCFR

# vapoursynth-mvtools
RUN git clone https://github.com/dubhater/vapoursynth-mvtools && cd vapoursynth-mvtools && ./autogen.sh && ./configure && make -j$(nproc) && make install && \
    cd /workspace && rm -rf vapoursynth-mvtools

# fmtconv
RUN git clone https://github.com/EleonoreMizo/fmtconv && cd fmtconv/build/unix/ && ./autogen.sh && ./configure && make -j$(nproc) && make install && \
    cd /workspace && rm -rf fmtconv

# akarin vs
RUN apt install llvm-12 llvm-12-dev -y && git clone https://github.com/AkarinVS/vapoursynth-plugin && \
    cd vapoursynth-plugin && meson build && ninja -C build && \
    ninja -C build install && cd /workspace && rm -rf vapoursynth-plugin

# scxvid
RUN apt install libxvidcore-dev -y && apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y && \
    git clone https://github.com/dubhater/vapoursynth-scxvid && cd vapoursynth-scxvid && ./autogen.sh && ./configure && make -j$(nproc) && make install && \
    cd /workspace && rm -rf vapoursynth-scxvid

# wwxd
RUN git clone https://github.com/dubhater/vapoursynth-wwxd && cd vapoursynth-wwxd && \
    gcc -o libwwxd.so -fPIC -shared -O2 -Wall -Wextra -Wno-unused-parameter $(pkg-config --cflags vapoursynth) src/wwxd.c src/detection.c && \
    cp libwwxd.so /usr/local/lib/libwwxd.so && cd /workspace && rm -rf vapoursynth-wwxd

# lsmash
# compiling ffmpeg because apt packages are too old (ffmpeg4.4 because 5 fails to compile)
# using shared to avoid -fPIC https://ffmpeg.org/pipermail/libav-user/2014-December/007720.html
RUN git clone https://github.com/FFmpeg/FFmpeg && cd FFmpeg && git switch release/4.4 && git checkout de1132a89113b131831d8edde75214372c983f32 && \
    CFLAGS=-fPIC ./configure --enable-shared --disable-static --enable-pic && make -j$(nproc) && make install && ldconfig && cd /workspace && rm -rf FFmpeg && \
    git clone https://github.com/l-smash/l-smash && cd l-smash && CFLAGS=-fPIC ./configure --disable-static --enable-shared  && make -j$(nproc) && make install && cd /workspace && rm -rf l-smash && \
    git clone https://github.com/AkarinVS/L-SMASH-Works && cd L-SMASH-Works/VapourSynth/ && meson build && ninja -C build && ninja -C build install && \
    cd /workspace && rm -rf L-SMASH-Works && ldconfig

# deleting files
RUN rm -rf 1.3.231.2 cmake-3.23.0-rc1-linux-x86_64.sh zimg vapoursynth-R61

# move trtexec so it can be globally accessed
RUN mv /usr/src/tensorrt/bin/trtexec /usr/bin 

########################
# RealBasicVSR_x4 will download this if you dont download it prior
#RUN wget "https://download.pytorch.org/models/vgg19-dcbb9e9d.pth" -P /root/.cache/torch/hub/checkpoints/

# using own custom compiled ffmpeg
RUN wget https://github.com/styler00dollar/VSGAN-tensorrt-docker/releases/download/models/ffmpeg && \
    chmod +x ffmpeg && rm -rf /usr/local/bin/ffmpeg && mv ffmpeg /usr/local/bin/ffmpeg

# install custom opencv for av1
RUN apt install libtbb2 libgtk2.0-0 -y && apt-get autoclean -y && apt-get autoremove -y && apt-get clean -y && \
    pip install https://github.com/styler00dollar/opencv-python/releases/download/4.6.0.3725898/opencv_contrib_python-4.6.0.3725898-cp38-cp38-linux_x86_64.whl 

ENV CUDA_MODULE_LOADING=LAZY
WORKDIR /workspace/tensorrt
