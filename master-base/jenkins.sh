#! /bin/bash -e

default_version=$(cat /tmp/release.version)
JENKINS_SLAVE_IMAGE_TAG=${JENKINS_SLAVE_IMAGE_TAG:-${default_version}}

source /usr/local/bin/jenkins-common.sh
source /usr/local/bin/kube-slave-common.sh

shopt -s dotglob

function create_jenkins_config_xml() {
  # copy the default configuration from the image into the jenkins config path (which should be a volume for persistence).
  if [ ! -f "${image_config_path}" ]; then
    # If it contains a template (tpl) file, we can do additional manipulations to customize
    # the configuration.
    if [ -f "${image_config_path}.tpl" ]; then
      export KUBERNETES_CONFIG=$(generate_kubernetes_config)
      echo "Generating kubernetes-plugin configuration (${image_config_path}.tpl) ..."
      # we check the value of KUBE_CA here too, but print an informational message
      # in the log here, vs. simply not including it in the config returned by the echo
      # performed in generate_kubernetes_config
      if [ ! -z "${KUBE_CA}" ]; then
        openssl x509 -in $KUBE_CA > /dev/null
        if [ $? -eq 1 ] ; then
            echo "The file referenced by the KUBE_CA environment variable does not have a valid x509 certificate."
            echo "You will need to manually configure the server certificate used by the kubernetes-plugin."
        fi
      fi
      export ADMIN_MON_CONFIG=$(generate_administrative_monitors_config)
      echo "Generating administrative monitor configuration (${image_config_path}.tpl) ..."
      envsubst < "${image_config_path}.tpl" > "${image_config_path}"
    fi
  fi
}

function generate_administrative_monitors_config() {
  if [[ "${DISABLE_ADMINISTRATIVE_MONITORS}" == "true" ]]; then
      echo '
        <string>hudson.model.UpdateCenter$CoreUpdateMonitor</string>
        <string>jenkins.security.UpdateSiteWarningsMonitor</string>
      '
      return
  fi
  echo ""
}

function create_jenkins_credentials_xml() {
  if [ ! -f "${image_config_dir}/credentials.xml" ]; then
    if [ -f "${image_config_dir}/credentials.xml.tpl" ]; then
      if [ ! -z "${KUBERNETES_CONFIG}" ]; then
        echo "Generating kubernetes-plugin credentials (${JENKINS_HOME}/credentials.xml.tpl) ..."
        export KUBERNETES_CREDENTIALS=$(generate_kubernetes_credentials)
      fi
      # Fix the envsubst trying to substitute the $Hash inside credentials.xml
      export Hash="\$Hash"
      envsubst < "${image_config_dir}/credentials.xml.tpl" > "${image_config_dir}/credentials.xml"
    fi
  fi
}

function create_jenkins_config_from_templates() {
  find ${image_config_dir} -type f -name "*.tpl" -print0 | while IFS= read -r -d '' template_path; do
    local target_path=${template_path%.tpl}
    echo "target_path ${target_path}"
    if [[ ! -f "${target_path}" ]]; then
      if [[ "${target_path}" == "${image_config_path}" ]]; then
        create_jenkins_config_xml
      elif [[ "${target_path}" == "${image_config_dir}/credentials.xml" ]]; then
        create_jenkins_credentials_xml
      else
        # Allow usage of environment variables in templated files, e.g. ${DOLLAR}MY_VAR is replaced by $MY_VAR
        DOLLAR='$' envsubst < "${template_path}" > "${target_path}"
      fi
    fi
  done
}

CONTAINER_MEMORY_IN_BYTES=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
CONTAINER_MEMORY_IN_MB=$((CONTAINER_MEMORY_IN_BYTES/2**20))

echo "OPENSHIFT_JENKINS_JVM_ARCH='${OPENSHIFT_JENKINS_JVM_ARCH}', CONTAINER_MEMORY_IN_MB='${CONTAINER_MEMORY_IN_MB}'"

image_config_dir="/usr/share/jenkins/ref"
image_config_path="${image_config_dir}/config.xml"

if [[ -z "${JAVA_TOOL_OPTIONS}" ]]; then
  # these options will automatically be picked up by any JVM process but can
  # be overridden on that process' command line.
  JAVA_TOOL_OPTIONS="-XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Dsun.zip.disableMemoryMapping=true"
  export JAVA_TOOL_OPTIONS
fi

  if [[ -z "$CONTAINER_HEAP_PERCENT" ]]; then
      CONTAINER_HEAP_PERCENT=0.50
  fi

  CONTAINER_HEAP_MAX=$(echo "${CONTAINER_MEMORY_IN_MB} ${CONTAINER_HEAP_PERCENT}" | awk '{ printf "%d", $1 * $2 }')
  if [[ $JENKINS_MAX_HEAP_UPPER_BOUND_MB && $CONTAINER_HEAP_MAX -gt $JENKINS_MAX_HEAP_UPPER_BOUND_MB ]]; then
    CONTAINER_HEAP_MAX=$JENKINS_MAX_HEAP_UPPER_BOUND_MB
  fi
  if [[ -z "$JAVA_MAX_HEAP_PARAM" ]]; then
    JAVA_MAX_HEAP_PARAM="-Xmx${CONTAINER_HEAP_MAX}m"
  fi

  if [[ "$CONTAINER_INITIAL_PERCENT" ]]; then
    CONTAINER_INITIAL_HEAP=$(echo "${CONTAINER_HEAP_MAX} ${CONTAINER_INITIAL_PERCENT}" | awk '{ printf "%d", $1 * $2 }')
    if [[ -z "$JAVA_INITIAL_HEAP_PARAM" ]]; then
      JAVA_INITIAL_HEAP_PARAM="-Xms${CONTAINER_INITIAL_HEAP}m"
    fi
  fi


if [[ -z "$JAVA_GC_OPTS" ]]; then
  # See https://developers.redhat.com/blog/2014/07/22/dude-wheres-my-paas-memory-tuning-javas-footprint-in-openshift-part-2/ .
  # The values are aggressively set with the intention of relaxing GC CPU time
  # restrictions to enable it to free as much as possible, as well as
  # encouraging the GC to free unused heap memory back to the OS.
  JAVA_GC_OPTS="-XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90"
fi

if [[ "${USE_JAVA_DIAGNOSTICS}" || "${JAVA_DIAGNOSTICS}" ]]; then
  echo "Warning: USE_JAVA_DIAGNOSTICS and JAVA_DIAGNOSTICS are legacy and may be removed in a future version of this script."
fi

if [[ "${USE_JAVA_DIAGNOSTICS}" ]]; then
  JAVA_DIAGNOSTICS="-XX:NativeMemoryTracking=summary -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCTimeStamps -XX:+UnlockDiagnosticVMOptions"
fi

if [[ "${CONTAINER_CORE_LIMIT}" ]]; then
  JAVA_CORE_LIMIT="-XX:ParallelGCThreads=${CONTAINER_CORE_LIMIT} -Djava.util.concurrent.ForkJoinPool.common.parallelism=${CONTAINER_CORE_LIMIT} -XX:CICompilerCount=2"
fi

# Since OpenShift runs this Docker image under random user ID, we have to assign
# the 'jenkins' user name to this UID.
generate_passwd_file

if [ ! -e ${JENKINS_HOME}/configured ]; then
  # This container hasn't been configured yet
  create_jenkins_config_from_templates
  #create_jenkins_config_xml
  #create_jenkins_credentials_xml
  touch ${JENKINS_HOME}/configured
fi

## originals starts from here 
#
#
: "${JENKINS_WAR:="/usr/share/jenkins/jenkins.war"}"
: "${JENKINS_HOME:="/var/jenkins_home"}"
touch "${COPY_REFERENCE_FILE_LOG}" || { echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?"; exit 1; }
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ \( -type f -o -type l \) -exec bash -c '. /usr/local/bin/jenkins-support; for arg; do copy_reference_file "$arg"; done' _ {} +

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then

  # read JAVA_OPTS and JENKINS_OPTS into arrays to avoid need for eval (and associated vulnerabilities)
  java_opts_array=()
  while IFS= read -r -d '' item; do
    java_opts_array+=( "$item" )
  done < <([[ $JAVA_OPTS ]] && xargs printf '%s\0' <<<"$JAVA_OPTS")

  jenkins_opts_array=( )
  while IFS= read -r -d '' item; do
    jenkins_opts_array+=( "$item" )
  done < <([[ $JENKINS_OPTS ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

  exec java -Duser.home="$JENKINS_HOME" "${java_opts_array[@]}" -jar ${JENKINS_WAR} "${jenkins_opts_array[@]}" "$@"
fi

# As argument is not jenkins, assume user want to run his own process, for example a `bash` shell to explore this image
exec "$@"
