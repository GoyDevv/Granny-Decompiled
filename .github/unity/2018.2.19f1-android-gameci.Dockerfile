FROM unityci/editor:ubuntu-2018.2.19f1-android-3

SHELL ["/bin/bash", "-lc"]

# Unity 2018.2's GameCI image predates the editor metadata that
# game-ci/unity-builder@v4 expects in /usr/bin/unity-editor.d/*.
# Discover the SDK/JDK actually present in the image and publish the
# metadata in the format expected by the v4 Android entrypoint.
RUN set -euxo pipefail; \
    SDKMANAGER="$(find /opt /usr -type f -name sdkmanager 2>/dev/null | head -n 1 || true)"; \
    if [[ -z "${SDKMANAGER}" ]]; then \
      echo 'ERROR: sdkmanager is not present in the Unity 2018.2 Android image.' >&2; \
      exit 1; \
    fi; \
    if [[ "${SDKMANAGER}" == */cmdline-tools/* ]]; then \
      ANDROID_HOME_DIRECTORY="${SDKMANAGER%%/cmdline-tools/*}"; \
    elif [[ "${SDKMANAGER}" == */tools/bin/* ]]; then \
      ANDROID_HOME_DIRECTORY="${SDKMANAGER%%/tools/bin/*}"; \
    else \
      ANDROID_HOME_DIRECTORY="$(dirname "$(dirname "${SDKMANAGER}")")"; \
    fi; \
    JAVA_BIN="$(command -v java || true)"; \
    if [[ -n "${JAVA_BIN}" ]]; then \
      JAVA_HOME_DIRECTORY="$(dirname "$(dirname "$(readlink -f "${JAVA_BIN}")")")"; \
    else \
      JAVA_HOME_DIRECTORY=""; \
    fi; \
    mkdir -p /usr/bin/unity-editor.d; \
    { \
      [[ -n "${JAVA_HOME_DIRECTORY}" ]] && echo "JAVA_HOME=${JAVA_HOME_DIRECTORY}"; \
      echo "ANDROID_HOME=${ANDROID_HOME_DIRECTORY}"; \
    } > /usr/bin/unity-editor.d/gameci-compat; \
    echo "Configured ANDROID_HOME=${ANDROID_HOME_DIRECTORY}"; \
    echo "Configured sdkmanager=${SDKMANAGER}"; \
    [[ -x "${SDKMANAGER}" ]];
