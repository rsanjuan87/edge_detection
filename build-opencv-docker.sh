#!/bin/bash
# Compile OpenCV 4.10.0 with 16KB page size support using Docker
# Requiere: Docker instalado en macOS

set -e

OPENCV_VERSION="4.10.0"
ANDROID_NDK_VERSION="r26b"
OUTPUT_DIR="$(pwd)/opencv-build-output"
DOCKER_IMAGE="ubuntu:22.04"

echo "🔧 Building OpenCV $OPENCV_VERSION with 16KB page support..."
echo "📦 Using Android NDK $ANDROID_NDK_VERSION"
echo "📁 Output directory: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

# Docker build command
docker run --rm \
  -v "$OUTPUT_DIR":/workspace/output \
  --workdir /workspace \
  $DOCKER_IMAGE bash -c '
    set -e
    
    # Update system
    apt-get update && apt-get install -y \
        build-essential \
        cmake \
        git \
        wget \
        python3 \
        java-11-openjdk-headless \
        zip \
        unzip
    
    echo "📥 Downloading Android NDK r26b..."
    wget -q https://dl.google.com/android/repository/android-ndk-r26b-linux.zip
    unzip -q android-ndk-r26b-linux.zip
    export ANDROID_NDK=$(pwd)/android-ndk-r26b
    
    echo "📥 Downloading OpenCV 4.10.0..."
    wget -q https://github.com/opencv/opencv/archive/refs/tags/4.10.0.zip
    unzip -q 4.10.0.zip
    cd opencv-4.10.0
    
    echo "🔨 Configuring OpenCV for ARM64 with 16KB support..."
    mkdir -p build-arm64
    cd build-arm64
    
    # Flags específicos para 16KB page size
    export LDFLAGS="-Wl,-z,max-page-size=16384"
    export CFLAGS="-Wl,-z,max-page-size=16384"
    export CXXFLAGS="-Wl,-z,max-page-size=16384"
    
    cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_PLATFORM=android-24 \
        -DANDROID_STL=c++_static \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_JAVA=ON \
        -DBUILD_ANDROID_EXAMPLES=OFF \
        -DBUILD_DOCS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        -DBUILD_TESTS=OFF \
        -DCMAKE_CXX_FLAGS="-Wl,-z,max-page-size=16384" \
        -DCMAKE_C_FLAGS="-Wl,-z,max-page-size=16384" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-z,max-page-size=16384" \
        .. 2>&1 | tail -20
    
    echo "🔨 Compiling OpenCV (this may take 10-30 minutes)..."
    make -j$(nproc) 2>&1 | tail -20
    
    echo "📦 Creating AAR library..."
    # Create minimal Android archive
    mkdir -p /workspace/output/arm64-v8a
    cp lib/libopencv_java4.so /workspace/output/arm64-v8a/
    cp -r modules/java/src/org /workspace/output/
    
    echo "✅ OpenCV ARM64 build completed!"
    ls -lh /workspace/output/arm64-v8a/
  '

echo ""
echo "✅ Docker build completed!"
echo "📁 Output files in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Copy output files to: android/src/main/jniLibs/arm64-v8a/"
echo "2. Update build.gradle to use local OpenCV instead of Maven"
