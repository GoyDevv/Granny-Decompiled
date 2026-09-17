FROM unityci/editor:ubuntu-2018.2.19f1-android-3

SHELL ["/bin/bash", "-lc"]

# Unity 2018.x uses the legacy Android SDK layout. The published
# GameCI image for this editor can be missing sdkmanager, while the
# current unity-builder action expects ANDROID_HOME and sdkmanager to
# be discoverable inside the container.
ENV UNITY_PATH=/opt/Unity \
    ANDROID_INSTALL_LOCATION=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer \
    ANDROID_SDK_ROOT=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK \
    ANDROID_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK \
    ANDROID_NDK_VERSION=16.1.4479499 \
    ANDROID_NDK_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK/ndk/16.1.4479499 \
    ANDROID_BUILD_TOOLS_VERSION=28.0.3 \
    JAVA_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/Tools/OpenJDK/Linux

ENV PATH=${JAVA_HOME}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}

RUN set -euxo pipefail; \
    test -x "${UNITY_PATH}/Editor/Unity"; \
    test -d "${JAVA_HOME}"; \
    mkdir -p "${ANDROID_HOME}"; \
    chmod -R 777 "${ANDROID_INSTALL_LOCATION}"; \
    wget -q https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip -O /tmp/android-sdk.zip; \
    unzip -q /tmp/android-sdk.zip -d "${ANDROID_HOME}"; \
    yes | sdkmanager \
      "platform-tools" \
      "ndk;${ANDROID_NDK_VERSION}" \
      "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
      "platforms;android-26" \
      "platforms;android-27" \
      "platforms;android-28"; \
    yes | "${ANDROID_HOME}/tools/bin/sdkmanager" --licenses; \
    mkdir -p /usr/bin/unity-editor.d; \
    cat > /usr/bin/unity-editor.d/android-2018.3-4.sh <<'EOF'\nexport ANDROID_INSTALL_LOCATION=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer\nexport ANDROID_SDK_ROOT=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK\nexport ANDROID_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK\nexport ANDROID_NDK_VERSION=16.1.4479499\nexport ANDROID_NDK_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/SDK/ndk/16.1.4479499\nexport ANDROID_BUILD_TOOLS_VERSION=28.0.3\nexport JAVA_HOME=/opt/Unity/Editor/Data/PlaybackEngines/AndroidPlayer/Tools/OpenJDK/Linux\nexport PATH=${JAVA_HOME}/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:${PATH}\nEOF\n    chmod 644 /usr/bin/unity-editor.d/android-2018.3-4.sh; \
    echo '. /usr/bin/unity-editor.d/android-2018.3-4.sh' >> /root/.bashrc; \
    rm -f /tmp/android-sdk.zip; \
    test -x "${ANDROID_HOME}/tools/bin/sdkmanager"; \
    test -d "${ANDROID_NDK_HOME}"; \
    test -d "${ANDROID_HOME}/build-tools/${ANDROID_BUILD_TOOLS_VERSION}"; \
    test -d "${ANDROID_HOME}/platforms/android-28"; \
    echo "Unity 2018.2 Android SDK configured at ${ANDROID_HOME}"; \
    "${ANDROID_HOME}/tools/bin/sdkmanager" --list >/dev/null
