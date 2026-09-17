FROM unityci/editor:ubuntu-2018.2.19f1-android-3

SHELL ["/bin/bash", "-lc"]

# Unity 2018.2 predates Unity's bundled OpenJDK. The published GameCI image
# also lacks the legacy sdkmanager layout expected by unity-builder@v4.
# Install Java 8 plus the Android SDK/NDK toolchain used by this editor.
ENV UNITY_PATH=/opt/unity \
    ANDROID_INSTALL_LOCATION=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer \
    ANDROID_SDK_ROOT=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK \
    ANDROID_HOME=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK \
    ANDROID_NDK_VERSION=16.1.4479499 \
    ANDROID_NDK_HOME=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK/ndk/16.1.4479499 \
    ANDROID_BUILD_TOOLS_VERSION=28.0.3 \
    JAVA_HOME=/opt/jdk8

ENV PATH=${JAVA_HOME}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

RUN set -euxo pipefail; \
    test -x "${UNITY_PATH}/Editor/Unity"; \
    mkdir -p /opt/jdk8; \
    wget -q https://api.adoptium.net/v3/binary/latest/8/ga/linux/x64/jdk/hotspot/normal/eclipse -O /tmp/jdk8.tar.gz; \
    tar -xzf /tmp/jdk8.tar.gz --strip-components=1 -C /opt/jdk8; \
    test -x "${JAVA_HOME}/bin/java"; \
    java -version 2>&1 | head -n 1; \
    mkdir -p "${ANDROID_HOME}"; \
    chmod -R 777 "${ANDROID_INSTALL_LOCATION}"; \
    wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O /tmp/android-sdk.zip; \
    unzip -q /tmp/android-sdk.zip -d "${ANDROID_HOME}"; \
    yes | "${ANDROID_HOME}/tools/bin/sdkmanager" \
      "platform-tools" \
      "platforms;android-27" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "ndk;${ANDROID_NDK_VERSION}"; \
    yes | "${ANDROID_HOME}/tools/bin/sdkmanager" --licenses; \
    mkdir -p /usr/bin/unity-editor.d; \
    printf '%s\n' \
      'export ANDROID_INSTALL_LOCATION=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer' \
      'export ANDROID_SDK_ROOT=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK' \
      'export ANDROID_HOME=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK' \
      'export ANDROID_NDK_VERSION=16.1.4479499' \
      'export ANDROID_NDK_HOME=/opt/unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK/ndk/16.1.4479499' \
      'export ANDROID_BUILD_TOOLS_VERSION=28.0.3' \
      'export JAVA_HOME=/opt/jdk8' \
      'export PATH=${JAVA_HOME}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}' \
      > /usr/bin/unity-editor.d/android-2018.2.sh; \
    chmod 644 /usr/bin/unity-editor.d/android-2018.2.sh; \
    echo '. /usr/bin/unity-editor.d/android-2018.2.sh' >> /root/.bashrc; \
    rm -f /tmp/jdk8.tar.gz /tmp/android-sdk.zip; \
    test -x "${JAVA_HOME}/bin/java"; \
    test -x "${ANDROID_HOME}/tools/bin/sdkmanager"; \
    test -d "${ANDROID_NDK_HOME}"; \
    test -d "${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"; \
    test -d "${ANDROID_HOME}/platforms/android-27"; \
    "${ANDROID_HOME}/tools/bin/sdkmanager" --list >/dev/null; \
    echo "Unity 2018.2 Android toolchain configured successfully"
