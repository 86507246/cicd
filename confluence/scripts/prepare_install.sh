#!/bin/bash

ATL_GENERATE_PASSWORD_SCRIPT="print(com.atlassian.security.password.DefaultPasswordEncoder.getDefaultInstance().encodePassword(arguments[0]));"
ATL_GENERATE_SERVER_ID_SCRIPT="print((new com.atlassian.license.DefaultSIDManager()).generateSID());"
ATL_GENERATE_JWT_KEYPAIR_SCRIPT='var keypairgen = java.security.KeyPairGenerator.getInstance("RSA");keypairgen.initialize(3072);var keypair = keypairgen.genKeyPair();var publicKey = keypair.getPublic().getEncoded();var privateKey = keypair.getPrivate().getEncoded();print(org.apache.commons.codec.binary.Base64.encodeBase64String(privateKey) +"~"+ org.apache.commons.codec.binary.Base64.encodeBase64String(publicKey));'

ATL_TEMP_DIR="/tmp"
ATL_CONFLUENCE_VARFILE="${ATL_CONFLUENCE_SHARED_HOME}/confluence.varfile"
ATL_MSSQL_DRIVER_VERSION="${CONFLUENCE_SQLSERVER_DRIVER_VERSION:-6.3.0.jre8-preview}"
ATL_MSSQL_DRIVER_FILENAME="mssql-jdbc-${ATL_MSSQL_DRIVER_VERSION}.jar"

function atl_log {
  local scope=$1
  local msg=$2
  local timestamp=`date +%Y-%m-%dT%H:%M:%S%z`
  echo "${timestamp}|[${scope}]: ${msg}"
}

function atl_error {
  atl_log "$1" "$2" >&2
}

function log {
  atl_log "${FUNCNAME[1]}" "$1"
}

function error {
  atl_error "${FUNCNAME[1]}" "$1"
  exit 3
}

function enable_nat {
  atl_log enable_nat "Enabling NAT"
  sysctl -w net.ipv4.ip_forward=1 >> /etc/sysctl.conf

  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

  iptables -t nat -A PREROUTING -p tcp -i eth0 --dport 80 -j DNAT --to-destination ${APP_GATEWAY_INTERNAL_IP}
  iptables -A FORWARD -i eth0 -p tcp -d ${APP_GATEWAY_INTERNAL_IP} --dport 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

  iptables -A FORWARD -i eth1 -o eth0 -j ACCEPT
  iptables -A FORWARD -i eth2 -o eth0 -j ACCEPT

  atl_log enable_nat "Persisting iptables rules"

  iptables-save > /etc/iptables.conf
  echo "iptables-restore -n < /etc/iptables.conf" >> /etc/rc.local
}

function enable_rc_local {
  atl_log enable_rc_local "Enabling rc.local execution on system startup"
  systemd enable rc-local.service
  [ ! -f /etc/rc.local ] && (echo '#!/bin/sh' > /etc/rc.local)
  [ ! -x /etc.rc.local ] && chmod +x /etc/rc.local
}

function tune_tcp_keepalive_for_azure {
  # Values taken from https://docs.microsoft.com/en-us/sql/connect/jdbc/connecting-to-an-azure-sql-database
  # Windows values are milliseconds, Linux values are seconds

  atl_log tune_tcp_keepalive_for_azure "Tuning TCP KeepAlive settings for Azure..."
  atl_log tune_tcp_keepalive_for_azure "Old values: "$'\n'"$(sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes)"

  local new_values="$(sysctl -w \
    net.ipv4.tcp_keepalive_time=30 \
    net.ipv4.tcp_keepalive_intvl=1 \
    net.ipv4.tcp_keepalive_probes=10 \
        | tee -a /etc/sysctl.conf)"
  atl_log tune_tcp_keepalive_for_azure "New values: "$'\n'"${new_values}"
}

function preserve_installer {
  local confluence_version=$(cat version)
  local confluence_installer="${ATL_CONFLUENCE_PRODUCT}-${confluence_version}-x64.bin"

  log "preserving ${ATL_CONFLUENCE_PRODUCT} installer ${confluence_installer} and metadata"
  cp installer ${ATL_CONFLUENCE_SHARED_HOME}/${confluence_installer}
  cp version ${ATL_CONFLUENCE_SHARED_HOME}/$ATL_CONFLUENCE_PRODUCT.version
  log "${ATL_CONFLUENCE_PRODUCT} installer ${confluence_installer} and metadata has been preserved"
}

function download_installer {
  if [ ${ATL_CONFLUENCE_VERSION} = 'latest' ]
  then
    log "using the latest version of confluence"
    local confluence_version_file_url="${LATEST_CONFLUENCE_PRODUCT_VERSION_URL}"
    log "Downloading installer description from ${confluence_version_file_url}"

    if ! curl -L -f --silent "${confluence_version_file_url}" -o "version" 2>&1
    then
        error "Could not download installer description from ${confluence_version_file_url}"
    fi
  else
    log "using version ${ATL_CONFLUENCE_VERSION} of confluence"
    echo -n "${ATL_CONFLUENCE_VERSION}" > version
  fi


  local confluence_version=$(cat version)
  local confluence_installer="${ATL_CONFLUENCE_PRODUCT}-${confluence_version}-x64.bin"
  local confluence_installer_url="${ATL_CONFLUENCE_RELEASES_BASE_URL}/${confluence_installer}"

  log "Downloading ${ATL_CONFLUENCE_PRODUCT} installer from ${confluence_installer_url}"

  if ! curl -L -f --silent "${confluence_installer_url}" -o "installer" 2>&1
  then
    error "Could not download ${ATL_CONFLUENCE_PRODUCT} installer from ${confluence_installer_url}"
  fi
}

function install_jq {
  apt-get update
  apt-get -qqy install jq
}

function prepare_password_generator {
  echo "${ATL_GENERATE_PASSWORD_SCRIPT}" > generate-password.js
}

function install_password_generator {
  apt-get -qqy install openjdk-8-jre-headless
  apt-get -qqy install maven

  if ! [ -f atlassian-password-encoder-3.2.3.jar ]; then
    mvn dependency:get -DremoteRepositories="${ATLASSIAN_MAVEN_REPOSITORY_URL}" -Dartifact=com.atlassian.security:atlassian-password-encoder:3.2.3 -Dtransitive=false -Ddest=.
  fi

  if ! [ -f commons-lang-2.6.jar ]; then
    mvn dependency:get -Dartifact=commons-lang:commons-lang:2.6 -Dtransitive=false -Ddest=.
  fi

  if ! [ -f commons-codec-1.9.jar ]; then
    mvn dependency:get -Dartifact=commons-codec:commons-codec:1.9 -Dtransitive=false -Ddest=.
  fi

  if ! [ -f bcprov-jdk15on-1.50.jar ]; then
    mvn dependency:get -Dartifact=org.bouncycastle:bcprov-jdk15on:1.50 -Dtransitive=false -Ddest=.
  fi
}

function run_password_generator {
  jjs -cp atlassian-password-encoder-3.2.3.jar:commons-lang-2.6.jar:commons-codec-1.9.jar:bcprov-jdk15on-1.50.jar generate-password.js -- $1
}

function prepare_server_id_generator {
  apt-get -qqy install openjdk-8-jre-headless
  apt-get -qqy install maven

  log "Downloading artifacts to prepare Server Id generator"

  if ! [ -f atlassian-extras-3.2.jar ]; then
    mvn dependency:get -DremoteRepositories="${ATLASSIAN_MAVEN_REPOSITORY_URL}" -Dartifact=com.atlassian.extras:atlassian-extras:3.2 -Dtransitive=false -Ddest=.
  fi

  log "Artefacts are ready"

  log "Preparing Server Id generation script"
  echo "${ATL_GENERATE_SERVER_ID_SCRIPT}" > generate-serverid.js
  log "Server Id generation script is ready"
}

function generate_server_id {
  jjs -cp atlassian-extras-3.2.jar generate-serverid.js
}

function prepare_jwt_keypair_generator {
  apt-get -qqy install openjdk-8-jre-headless
  apt-get -qqy install maven

  log "Downloading artifacts to prepare JWT keypair generator"

  if ! [ -f commons-codec-1.9.jar ]; then
    mvn dependency:get -Dartifact=commons-codec:commons-codec:1.9 -Dtransitive=false -Ddest=.
  fi

  log "Artefacts are ready"

  log "Preparing JWT keypair generation script"
  echo "${ATL_GENERATE_JWT_KEYPAIR_SCRIPT}" > genkeypair.js
  log "JWT keypair generation script is ready"
}

function generate_jwt_keypair {
  jjs -cp commons-codec-1.9.jar genkeypair.js
}

# issue_signed_request
#   <verb> - GET/PUT/POST
#   <url> - the resource uri to actually post
#   <canonical resource> - the canonicalized resource uri
# see https://msdn.microsoft.com/en-us/library/azure/dd179428.aspx for details
function issue_signed_request {
  request_method="$1"
  request_url="$2"
  canonicalized_resource="/${STORAGE_ACCOUNT}/$3"
  access_key="$4"

  request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
  storage_service_version="2015-04-05"
  authorization="SharedKey"
  full_url="${FILE_STORE_URL_DOMAIN}${request_url}"

  x_ms_date_h="x-ms-date:$request_date"
  x_ms_version_h="x-ms-version:$storage_service_version"
  canonicalized_headers="${x_ms_date_h}\n${x_ms_version_h}\n"
  content_length_header="Content-Length:0"

  string_to_sign="${request_method}\n\n\n\n\n\n\n\n\n\n\n\n${canonicalized_headers}${canonicalized_resource}"
  decoded_hex_key="$(echo -n "${access_key}" | base64 -d -w0 | xxd -p -c256)"
  signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary |  base64 -w0)
  authorization_header="Authorization: $authorization ${STORAGE_ACCOUNT}:$signature"

  curl -sw "/status/%{http_code}/\n" \
       -X $request_method \
       -H "$x_ms_date_h" \
       -H "$x_ms_version_h" \
       -H "$authorization_header" \
       -H "$content_length_header" \
       $full_url
}

function validate {
  if [ ! "$1" ];
  then
    error "response was null"
  fi

  if [[ $(echo ${1} | grep -o "/status/2") || $(echo ${1} | grep -o "/status/409") ]];
  then
    # response is valid or share already exists, ignore
    return
  else
    # other or unknown status
    if [ $(echo ${1} | grep -o "/status/") ];
    then
      error "response was not valid: ${1}"
    else
      error "no response code found: ${1}"
    fi
  fi
}

function list_shares {
  local access_key="$1"
  response="$(issue_signed_request GET ?comp=list "\ncomp:list" "${access_key}")"
  echo ${response}
}

function create_share {
  log "creating share ${ATL_CONFLUENCE_SHARED_HOME_NAME}"

  local url="${ATL_CONFLUENCE_SHARED_HOME_NAME}?restype=share"
  local res="${ATL_CONFLUENCE_SHARED_HOME_NAME}\nrestype:share"

  # test whether share exists already
  response=$(list_shares "${STORAGE_KEY}")
  validate "$response"
  exists=$(echo ${response} | grep -c "<Share><Name>${ATL_CONFLUENCE_SHARED_HOME_NAME}</Name>")

  if [ ${exists} -eq 0 ];
  then
    # create share
    response=$(issue_signed_request "PUT" ${url} ${res} "${STORAGE_KEY}")
    validate "${response}"
  fi
}

function mount_share {
  local persist="$1"
  local uid=${2:-0}
  local gid=${3:-0}
  creds_file="/etc/cifs.${ATL_CONFLUENCE_SHARED_HOME_NAME}"
  mount_options="vers=3.0,uid=${uid},gid=${gid},dir_mode=0750,file_mode=0640,credentials=${creds_file}"
  mount_share="$(echo ${FILE_STORE_URL_DOMAIN} | sed 's/https://')${ATL_CONFLUENCE_SHARED_HOME_NAME}"

  log "creating credentials at ${creds_file}"
  echo "username=${STORAGE_ACCOUNT}" >> ${creds_file}
  echo "password=${STORAGE_KEY}" >> ${creds_file}
  chmod 600 ${creds_file}

  log "mounting share $share_name at ${ATL_CONFLUENCE_SHARED_HOME}"

  if [ $(cat /etc/mtab | grep -o "${ATL_CONFLUENCE_SHARED_HOME}") ];
  then
    log "location ${ATL_CONFLUENCE_SHARED_HOME} is already mounted"
    return 0
  fi

  [ -d "${ATL_CONFLUENCE_SHARED_HOME}" ] || mkdir -p "${ATL_CONFLUENCE_SHARED_HOME}"
  mount -t cifs ${mount_share} ${ATL_CONFLUENCE_SHARED_HOME} -o ${mount_options}

  if [ ! $(cat /etc/mtab | grep -o "${ATL_CONFLUENCE_SHARED_HOME}") ];
  then
    error "mount failed"
  fi

  if [ ${persist} ];
  then
    # create a backup of fstab
    cp /etc/fstab /etc/fstab_backup

    # update /etc/fstab
    echo ${mount_share} ${ATL_CONFLUENCE_SHARED_HOME} cifs ${mount_options} >> /etc/fstab

    # test that mount works
    umount ${ATL_CONFLUENCE_SHARED_HOME}
    mount ${ATL_CONFLUENCE_SHARED_HOME}

    if [ ! $(cat /etc/mtab | grep -o "${ATL_CONFLUENCE_SHARED_HOME}") ];
    then
      # revert changes
      cp /etc/fstab_backup /etc/fstab
      error "/etc/fstab was not configured correctly, changes reverted"
    fi
  fi

  log "Waiting a bit to make sure that share is readable"
  sleep 10s
  sync
  sleep 10s
  log "Waiting completed"
}

function prepare_share {
  create_share
  mount_share 1
}

function hydrate_shared_config {
  export DB_TRUSTED_HOST=$(get_trusted_dbhost)

  export SERVER_ID=`generate_server_id`
  atl_log hydrate_shared_config "Generated server id [${SERVER_ID}]"
  local _JWT_KEYPAIR=`generate_jwt_keypair`
  export CONFLUENCE_JWT_PRIVATE_KEY=`echo ${_JWT_KEYPAIR} | cut -d '~' -f1`
  export CONFLUENCE_JWT_PUBLIC_KEY=`echo ${_JWT_KEYPAIR} | cut -d '~' -f2`
  atl_log hydrate_shared_config "Generated JWT public key  :${CONFLUENCE_JWT_PUBLIC_KEY}"
  atl_log hydrate_shared_config "Generated JWT private key :${CONFLUENCE_JWT_PRIVATE_KEY}"

  local template_files=(home-confluence.cfg.xml.template shared-confluence.cfg.xml.template server.xml.template setenv.sh.template install_synchrony_service.sh.template)
  local output_file=""
  for template_file in ${template_files[@]};
  do
    output_file=`echo "${template_file}" | sed 's/\.template$//'`
    atl_log hydrate_shared_config "Start hydrating '${template_file}' into '${output_file}'"
    cat ${template_file} | python3 hydrate_confluence_config.py > ${output_file}
    atl_log hydrate_shared_config "Hydrated '${template_file}' into '${output_file}'"
  done
}

function copy_artefacts {
  local excluded_files=(std* version *.bin *.jar prepare_install.sh *.py *.template *.sql *.js)

  local exclude_rules=""
  for file in ${excluded_files[@]};
  do
    exclude_rules="--exclude ${file} ${exclude_rules}"
  done

  rsync -av ${exclude_rules} * ${ATL_CONFLUENCE_SHARED_HOME}
  log "cleaning up old node.id files..."
  rm -rfv ${ATL_CONFLUENCE_SHARED_HOME}/node.id.*
  rm -rfv ${ATL_CONFLUENCE_SHARED_HOME}/synchrony.id.*
}

function hydrate_db_dump {
  export USER_ENCRYPTION_METHOD="atlassian-security"

  export USER_PASSWORD=`run_password_generator ${USER_CREDENTIAL}`

  export USER_FIRSTNAME=`echo ${USER_FULLNAME} | cut -d ' ' -f 1`
  export USER_LASTNAME=`echo ${USER_FULLNAME} | cut -d ' ' -f 2-`

  export USER_FIRSTNAME_LOWERCASE=`echo ${USER_FULLNAME_LOWERCASE} | cut -d ' ' -f 1`
  export USER_LASTNAME_LOWERCASE=`echo ${USER_FULLNAME_LOWERCASE} | cut -d ' ' -f 2-`

  log "Prepare database dump [user=${USER_NAME}, password=${USER_PASSWORD}, credential=${USER_CREDENTIAL}]"

  local template_files=(configuredb.sql.template tables.sql.template data.sql.template index.sql.template constraints.sql.template)
  local output_file=""
  for template_file in ${template_files[@]};
  do
    output_file=`echo "${template_file}" | sed 's/\.template$//'`
    log "Start hydrating '${template_file}' into '${output_file}'"
    cat ${template_file} | python3 hydrate_confluence_config.py > ${output_file}
    log "Hydrated '${template_file}' into '${output_file}'"
  done
}

function install_liquibase {
  atl_log install_liquibase "Downloading liquibase"
  if ! [ -f liquibase-core-3.5.3.jar ] ;  then
    mvn dependency:get -Dartifact=org.liquibase:liquibase-core:3.5.3 -Dtransitive=false -Ddest=.
    atl_log install_liquibase "Liquibase has been downloaded"
  else
    atl_log install_liquibase "Liquibase file found: not downloading."
  fi

  atl_log install_liquibase "Preparing liquibase migration file"

  cat <<EOT >> "databaseChangeLog.xml"
<databaseChangeLog
    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns:ext="http://www.liquibase.org/xml/ns/dbchangelog-ext"
    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-3.1.xsd
    http://www.liquibase.org/xml/ns/dbchangelog-ext http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-ext.xsd">
    <changeSet id="1" author="confluence">
      <sqlFile dbms="mssql"
               encoding="utf8"
               endDelimiter=";"
               path="configuredb.sql"
               relativeToChangelogFile="true" />
      <sqlFile dbms="mssql"
               encoding="utf8"
               endDelimiter=";"
               path="tables.sql"
               relativeToChangelogFile="true" />
      <sqlFile dbms="mssql"
               encoding="utf8"
               endDelimiter=";"
               path="data.sql"
               relativeToChangelogFile="true" />
      <sqlFile dbms="mssql"
               encoding="utf8"
               endDelimiter=";"
               path="index.sql"
               relativeToChangelogFile="true" />
      <sqlFile dbms="mssql"
               encoding="utf8"
               endDelimiter=";"
               path="constraints.sql"
               relativeToChangelogFile="true" />
    </changeSet>
</databaseChangeLog>
EOT

  atl_log install_liquibase "Prepared liquibase migration file"
}

function prepare_database {
  atl_log prepare_database "Installing liquibase"
  install_liquibase
  atl_log prepare_database "liquibase has been installed"
  atl_log prepare_database "ready to hydrate db dump"
  hydrate_db_dump
}

function get_trusted_dbhost {
  local host=$(echo "${DB_SERVER_NAME}" | cut -d . -f 2-)
  echo "*.${host}"
}

function apply_database_dump {
  log 'applying database dump'
  java  \
    -cp liquibase-core-3.5.3.jar:${ATL_MSSQL_DRIVER_FILENAME} \
    liquibase.integration.commandline.Main \
    --driver=com.microsoft.sqlserver.jdbc.SQLServerDriver \
    --url="jdbc:sqlserver://${DB_SERVER_NAME}:1433;database=${DB_NAME};encrypt=true;trustServerCertificate=false;hostNameInCertificate=${DB_TRUSTED_HOST};loginTimeout=30;" \
    --username="${DB_USER}@${DB_SERVER_NAME}" \
    --password="${DB_PASSWORD}" \
    --changeLogFile=databaseChangeLog.xml \
    update
}

function prepare_env {
  for var in `printenv | grep _ATL_ENV_DATA`; do log $var; done
  for var in `printenv | grep _ATL_ENV_DATA | cut -d "=" -f 1`; \
    do printf '%s\n' "${!var}" | \
        base64 --decode | \
        jq -r '.[] | "export " + .name + "=" + "\"" + .value + "\""' \
           >> exportenv.sh; \
    done

  echo "export STORAGE_KEY='${1}'" >> exportenv.sh
  source exportenv.sh
  export SERVER_AZURE_DOMAIN="${2}"
  export DB_SERVER_NAME="${3}"
  export SERVER_PROXY_NAME="${SERVER_CNAME:-${SERVER_AZURE_DOMAIN}}"
  export SYNCHRONY_CONTEXT_PATH="/synchrony"
  export SYNCHRONY_SERVICE_URL="${SERVER_APP_SCHEME}://${SERVER_PROXY_NAME}${SYNCHRONY_CONTEXT_PATH}"
}

function prepare_varfile {
  atl_log prepare_varfile "Preparing var file"

  cat <<EOT >> "${ATL_CONFLUENCE_VARFILE}"
launch.application\$Boolean=false
executeLauncherAction\$Boolean=false
app.install.service\$Boolean=true
portChoice=custom
httpPort\$Long=${SERVER_APP_PORT}
rmiPort\$Long=8000
existingInstallationDir=${ATL_CONFLUENCE_INSTALL_DIR}
sys.installationDir=${ATL_CONFLUENCE_INSTALL_DIR}
app.confHome=${ATL_CONFLUENCE_HOME}
sys.confirmedUpdateInstallationString=false
sys.languageId=en
EOT

  atl_log prepare_varfile "varfile is ready:"
  printf "`cat ${ATL_CONFLUENCE_VARFILE}`\n"
}

# Copies the proper version of CONFLUENCE's installer from shared home location
# into temp directory
# CONFLUENCE's version to install is specified by version file
# So in theory we can have multiple installers in home directory.
# Kinda forward thinking about upgrades and ZDU
# Also it almost straight copy-paste from our AWS scripts
function restore_installer {
  local confluence_version=$(cat ${ATL_CONFLUENCE_SHARED_HOME}/${ATL_CONFLUENCE_PRODUCT}.version)
  local confluence_installer="${ATL_CONFLUENCE_PRODUCT}-${confluence_version}-x64.bin"

  log "Using existing installer ${confluence_installer} from ${ATL_CONFLUENCE_SHARED_HOME} mount"

  local installer_path="${ATL_CONFLUENCE_SHARED_HOME}/${confluence_installer}"
  local installer_target="${ATL_TEMP_DIR}/installer"

  if [[ -f ${installer_path} ]]; then
    cp ${installer_path} "${installer_target}"
    chmod 0700 "${installer_target}"
  else
    local msg="${ATL_CONFLUENCE_PRODUCT} installer ${confluence_installer} ca been requested but unable to locate it in ${ATL_CONFLUENCE_SHARED_HOME}"
    log "${msg}"
    error "${msg}"
  fi

  log "Restoration of ${ATL_CONFLUENCE_PRODUCT} installer ${confluence_installer} has been completed"
}

function ensure_readable {
  local path=$1

  local timeout=300
  local interval=10

  local start=$(date +%s)

  log "Making sure to be able to read [file=${path}]"
  while true; do
    if [[ ! -f "${path}" ]]; then
      local end=$(date +%s)
      if [[ $(($end - $start)) -gt $timeout ]]; then
        error "Failed to ensure to be able to read [file=${path}]"
      else
        log "Unable to read [file=${path}], retrying..."
        log "$(($timeout - ($end - $start))) seconds left"
        sleep ${interval}s
        sync
      fi
    else
      return 0
    fi
  done
}

# Check if we already have installer in shared home and restores it if we do
# otherwise just downloads the installer and puts it into shared home
function prepare_installer {
  log "Checking if installer has been downloaded aready"
  ensure_readable "${ATL_CONFLUENCE_SHARED_HOME}/${ATL_CONFLUENCE_PRODUCT}.version"
  if [[ -f ${ATL_CONFLUENCE_SHARED_HOME}/${ATL_CONFLUENCE_PRODUCT}.version ]]; then
    log "Detected installer, restoring it"
    restore_installer
  else
    log "No installer has been found, downloading..."
    download_installer
    preserve_installer
  fi

  log "Installer is ready!"
}

# Check if fontconfig has been installed.
# Adoptopenjdk8 has a known bug with fontconfig missing, which will cause installer to fail
# Details see https://github.com/AdoptOpenJDK/openjdk-build/issues/693
function prepare_fontconfig {
  log "Installing fontconfig package..."
  apt update && apt install -y fontconfig

  log "Font config is ready!"
}

function perform_install {
  log "Ready to perform installation"

  log "Checking if ${ATL_CONFLUENCE_PRODUCT} has already been installed"
  if [[ -d "${ATL_CONFLUENCE_INSTALL_DIR}" ]]; then
    local msg="${ATL_CONFLUENCE_PRODUCT} install directory ${ATL_CONFLUENCE_INSTALL_DIR} already exists - aborting installation"
    error "${msg}"
  fi

  log "Creating ${ATL_CONFLUENCE_PRODUCT} install directory"
  mkdir -p "${ATL_CONFLUENCE_INSTALL_DIR}"

  log "Installing ${ATL_CONFLUENCE_PRODUCT} to ${ATL_CONFLUENCE_INSTALL_DIR}"
  sh "${ATL_TEMP_DIR}/installer" -q -varfile "${ATL_CONFLUENCE_VARFILE}" 2>&1
  log "Installed ${ATL_CONFLUENCE_PRODUCT} to ${ATL_CONFLUENCE_INSTALL_DIR}"

  log "Cleaning up..."
  rm -rf "${ATL_TEMP_DIR}"/installer* 2>&1

  chown -R confluence:confluence "${ATL_CONFLUENCE_INSTALL_DIR}"

  log "${ATL_CONFLUENCE_PDORUCT} installation completed"
}

function download_mssql_driver {
  atl_log install_mssql_driver "Downloading Microsoft database driver"

  if ! [ -f ${ATL_MSSQL_DRIVER_FILENAME} ] ; then
    mvn dependency:get -Dartifact=com.microsoft.sqlserver:mssql-jdbc:${ATL_MSSQL_DRIVER_VERSION} -Dtransitive=false -Ddest=.
  fi

  atl_log install_mssql_driver 'MS JDBC driver has been downloaded'
}

function get_node_ip {
  echo $(curl --silent -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-04-02" | jq -r ".network.interface[0].ipv4.ipAddress[0].privateIpAddress")
}

function get_unique_id {
  echo $(curl --silent -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-04-02" | jq -r ".compute.vmId")
}

function configure_cluster {
  local _all_possible_cluster_ips=`for n in {5..30}  ; do echo "10.0.2.${n}" ; done | tr '\n' ' ' | sed 's/ $//'`
  local _all_possible_nodes_ips=`echo "${_all_possible_cluster_ips}"`
  log "Checking all possible ips for existing nodes: ${_all_possible_nodes_ips}"
  declare -a _all_active_ips=($(for ip in ${_all_possible_cluster_ips}; do [[ `curl -o /dev/null -w "%{http_code}" --connect-timeout 1 --silent "http://${ip}:8080/status"` == 200 ]] && echo "${ip}" ; done))
  log "Found the following active nodes: [${_all_active_ips[@]}]"
  local expected_node_count=$((${ATL_CLUSTER_SIZE:-0} - ${!_all_active_ips[@]:-0}))
  if [ ${expected_node_count} -le 0 ] ; then
    error "error more nodes are running than expected! expected_node_count=${expected_node_count} vs ATL_CLUSTER_SIZE=${ATL_CLUSTER_SIZE} : ${_all_active_ips[@]}"
  else
    log "Expecting ${expected_node_count} more nodes to startup."
  fi
  local wait_time=$((${expected_node_count} * 20))
  local node_ip=`get_node_ip`
  local unique_node_id=`get_unique_id`
  echo ${node_ip} > ${ATL_CONFLUENCE_SHARED_HOME}/node.id.${unique_node_id}
  declare -a nodes=(${ATL_CONFLUENCE_SHARED_HOME}/node.id.*)
  ## block until all nodes come up
  while [ ${#nodes[@]} != ${expected_node_count} ];
  do
    log "found ${#nodes[@]} nodes"
    for n in ${nodes[@]} ; do
      log "node $n: `cat $n`"
    done
    log "expecting ${expected_node_count} nodes. Waiting ${wait_time} seconds for other nodes to come up..."
    sleep ${wait_time}
    nodes=(${ATL_CONFLUENCE_SHARED_HOME}/node.id.*)
  done
  ## found all nodes, export the peers' ip as an env variable for interpolation into the config *.xml files
  export CONFLUENCE_CLUSTER_PEERS=`cat ${ATL_CONFLUENCE_SHARED_HOME}/node.id.* | tr '\n' ',' | sed 's/,$//'`
  log "found all node ips: ${CONFLUENCE_CLUSTER_PEERS}"
  ## hydrate cluster configuration xml with the peer ips for hazelcast
  local template_files=(${ATL_CONFLUENCE_SHARED_HOME}/home-confluence.cfg.xml ${ATL_CONFLUENCE_SHARED_HOME}/shared-confluence.cfg.xml)
  local template_destination=(${ATL_CONFLUENCE_HOME}/confluence.cfg.xml       ${ATL_CONFLUENCE_SHARED_HOME}/confluence.cfg.xml)
  log "Configuring CONFLUENCE cluster at ${template_destination[@]}"
  for config_file_idx in ${!template_files[@]};
  do
    local template_file=${template_files[$config_file_idx]}
    local output_file=${template_destination[$config_file_idx]}
    log "Start hydrating '${template_file}' into '${output_file}'"
    cat ${template_file} | python3 hydrate_confluence_config.py > ${output_file}
    log "Hydrated '${template_file}' into '${output_file}'"
  done

  log "Cluster has been configured"
  ## startup mutex - we sort the list of nodes' unique_id lexographically, and only boot confluence for the node at the top of list,
  ## TODO: timeout (to prevent a bad node from blocking _everything_)
  local top_node=`echo ${nodes[@]} | tr ' ' '\n'  | sort | head -n1`
  local top_node_ip=$(cat ${top_node})
  while [ "${top_node_ip}" != "${node_ip}" ] ;
  do
    log "Node ${top_node} (${top_node_ip}) is being started up...waiting until it has finished..."
    log "Sleeping for ${wait_time} seconds"
    sleep ${wait_time}
    nodes=(${ATL_CONFLUENCE_SHARED_HOME}/node.id.*)
    top_node=`echo ${nodes[@]} | tr ' ' '\n'  | sort | head -n1`
    top_node_ip=$(cat ${top_node})
  done
  log "Node ${top_node} (${top_node_ip}) ready to be started..."
}

function get_confluence_ram {
  for mem in `free -m | grep "Mem:" | sed 's/\s\+/|/g' | cut -d '|' -f2`; do echo $((mem/100*75)); done
}

function configure_confluence_ram {
  local ram=`get_confluence_ram`
  export CONFLUENCE_MEMORY_MAX="${ram}m"
  log "Using ${CONFLUENCE_MEMORY_MAX} as java memory opts"
}

function configure_synchrony_service_url {
  log "setting up synchrony service URL"
  export SYNCHRONY_SERVICE_URL_OPTS="-Dsynchrony.service.url=${SYNCHRONY_SERVICE_URL}/v1 "
  log "setting up synchrony service URL Completed : ${SYNCHRONY_SERVICE_URL_OPTS}"
}

function configure_confluence {
  local confluence_configs=(${ATL_CONFLUENCE_SHARED_HOME}/setenv.sh          ${ATL_CONFLUENCE_SHARED_HOME}/server.xml)
  local confluence_configs_dest=(${ATL_CONFLUENCE_INSTALL_DIR}/bin/setenv.sh ${ATL_CONFLUENCE_INSTALL_DIR}/conf/server.xml)
  log "shared home contains:"
  ls -la ${ATL_CONFLUENCE_SHARED_HOME}
  log "Ready to configure CONFLUENCE startup env config files at ${confluence_configs_dest[@]}"
  configure_confluence_ram
  configure_synchrony_service_url
  for config_file_idx in ${!confluence_configs[@]};
  do
    local template_file=${confluence_configs[$config_file_idx]}
    local output_file=${confluence_configs_dest[$config_file_idx]}
    if [ -f ${template_file} ] ; then
      log "Start hydrating '${template_file}' into '${output_file}'"
      cat ${template_file} | python3 hydrate_confluence_config.py > ${output_file}
      log "Hydrated '${template_file}' into '${output_file}'"
    else
      error "${template_file} not found"
    fi
  done

  log "Configuring cluster..."
  configure_cluster
  log "Done configuring cluster!"
  chown -R confluence:confluence "/datadisks/disk1"
  chown -R confluence:confluence "${ATL_CONFLUENCE_HOME}"
}

function install_synchrony_service {
  apt-get -qqy install xmlstarlet
  local synchrony_package_jar="${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/packages/synchrony-standalone.jar"
  log "Setting up synchrony from ${synchrony_package_jar}"
  local confluence_home_dir="${ATL_CONFLUENCE_HOME}"
  local confluence_install_dir="${ATL_CONFLUENCE_INSTALL_DIR}"
  local tomcat_webapp_lib_dir="${ATL_CONFLUENCE_INSTALL_DIR}/confluence/WEB-INF/lib"

  log "using confluence home : [$confluence_home_dir]"

  local dbdriver_classpath=""
  log "using tomcat webapp lib dir: [${tomcat_webapp_lib_dir}]"
  for bundled_drivers in ${tomcat_webapp_lib_dir}/{postgresql-*.jar,mssql-jdbc-*.jar}
  do
     if [[ -f ${bundled_drivers} ]]; then
         log "found bundled driver [${bundled_drivers}]"
         dbdriver_classpath="${bundled_drivers}:${dbdriver_classpath}"
     fi
  done
  log "using classpath: [${dbdriver_classpath}]"

  local synchrony_file=${synchrony_package_jar}
  if [[ ! -f ${synchrony_file} ]]; then
     error "Failed to find file [${synchrony_file}]. Ensure that installation of confluence has been completed."
  fi
  log "using synchrony file: [${synchrony_file}]"

  local java_bin="${ATL_CONFLUENCE_INSTALL_DIR}/jre/bin/java"
  if [[ ! -f ${java_bin} ]]; then
     error "Failed to find java at [${java_bin}]. Ensure that installation of confluence has been completed"
  fi
  log "using java at [${java_bin}]"

  local confluence_cfg_xml_file="${ATL_CONFLUENCE_SHARED_HOME}/home-confluence.cfg.xml"
  if [[ ! -f ${confluence_cfg_xml_file} ]]; then
     error "Failed to find [${confluence_cfg_xml_file}]. Ensure that the NAT node has completed preparation first."
  fi
  log "using configuration file: [${confluence_cfg_xml_file}]"

  local jwt_private_key=$(xmlstarlet sel -t -v  '/confluence-configuration/properties/property[@name="jwt.private.key"]/text()' ${confluence_cfg_xml_file})
  log "using jwt_private_key : [${jwt_private_key}]"
  local jwt_public_key=$(xmlstarlet sel -t -v '/confluence-configuration/properties/property[@name="jwt.public.key"]/text()' ${confluence_cfg_xml_file})
  log "using jwt_public_key : [${jwt_public_key}]"
  local hibernate_connection_password=$(xmlstarlet sel -t -v '/confluence-configuration/properties/property[@name="hibernate.connection.password"]/text()' ${confluence_cfg_xml_file})
  log "using hibernate_connection_password : [${hibernate_connection_password}]"
  local hibernate_connection_username=$(xmlstarlet sel -t -v '/confluence-configuration/properties/property[@name="hibernate.connection.username"]/text()' ${confluence_cfg_xml_file})
  log "using hibernate_connection_username : [${hibernate_connection_username}]"
  local hibernate_connection_url=$(xmlstarlet sel -t -v '/confluence-configuration/properties/property[@name="hibernate.connection.url"]/text()' ${confluence_cfg_xml_file})
  log "using hibernate_connection_url : [${hibernate_connection_url}]"
  log "using SYNCHRONY_SERVICE_URL : [${SYNCHRONY_SERVICE_URL}]"
  local synchrony_port=${SERVER_SYNCHRONY_INTERNAL_PORT}
  local cluster_listen_port=5700
  local cluster_base_port=25500
  log "using synchrony port : [synchrony_port=${synchrony_port},cluster_listen_port=${cluster_listen_port},cluster_base_port=${cluster_base_port}]"
  local synchrony_mem="`get_confluence_ram`m"
  local synchrony_unique_node_id=`get_unique_id`
  local wait_time=$((${ATL_SYNCHRONY_CLUSTER_SIZE:-0} * 20))

  local _all_possible_cluster_ips=`for n in {5..30}  ; do echo "10.0.4.${n}" ; done | tr '\n' ' ' | sed 's/ $//'`
  local _all_possible_nodes_ips=`echo "${_all_possible_cluster_ips}"`
  log "Checking all possible ips for existing nodes: ${_all_possible_nodes_ips}"
  declare -a _all_active_ips=($(for ip in ${_all_possible_cluster_ips}; do [[ `curl -o /dev/null -w "%{http_code}" --connect-timeout 1 --silent "http://${ip}:${SERVER_SYNCHRONY_INTERNAL_PORT}/synchrony/heartbeat"` == 200 ]] && echo "${ip}" ; done))
  log "Found the following active nodes: [${_all_active_ips[@]}]"
  local expected_node_count=$((${ATL_SYNCHRONY_CLUSTER_SIZE:-0} - ${!_all_active_ips[@]:-0}))
  if [ ${expected_node_count} -le 0 ] ; then
    error "error more nodes are running than expected! expected_node_count=${expected_node_count} vs ATL_SYNCHRONY_CLUSTER_SIZE=${ATL_SYNCHRONY_CLUSTER_SIZE} : ${_all_active_ips[@]}"
  else
    log "Expecting ${expected_node_count} more nodes to startup."
  fi
  local node_ip=`get_node_ip`
  echo ${node_ip} > ${ATL_CONFLUENCE_SHARED_HOME}/synchrony.id.${synchrony_unique_node_id}
  declare -a nodes=(${ATL_CONFLUENCE_SHARED_HOME}/synchrony.id.*)
  local wait_time=$((${expected_node_count} * 20))
  ## block until all nodes come up
  while [ ${#nodes[@]} != ${expected_node_count} ];
  do
    log "found ${#nodes[@]} nodes"
    for n in ${nodes[@]} ; do
      log "node $n: `cat $n`"
    done
    log "expecting ${expected_node_count} nodes. Waiting ${wait_time} seconds for other nodes to come up..."
    sleep ${wait_time}
    nodes=(${ATL_CONFLUENCE_SHARED_HOME}/synchrony.id.*)
  done

  local cluster_members_ips=`cat ${ATL_CONFLUENCE_SHARED_HOME}/synchrony.id.* | tr '\n' ',' | sed 's/,$//'`

  local log4j_configuration_file=""
  if [[ -f ${ATL_CONFLUENCE_SHARED_HOME}/synchrony.log4j.properties ]] ; then
    log4j_configuration_file="-Dlog4j.configurationFile=${ATL_CONFLUENCE_SHARED_HOME}/synchrony.log4j.properties"
  fi

  local synchrony_cmd="${java_bin} \
  -classpath "${dbdriver_classpath}:${synchrony_file}" \
  -Xss2048k \
  -Xmx${synchrony_mem} \
  -Dsynchrony.port=${synchrony_port} \
  -Dsynchrony.cluster.impl=hazelcast-btf \
  -Dcluster.listen.port=${cluster_listen_port} \
  -Dcluster.join.type=tcpip \
  -Dcluster.join.tcpip.members=${cluster_members_ips} \
  -Dsynchrony.cluster.base.port=${cluster_base_port} \
  -Dsynchrony.cluster.bind=${node_ip} \
  -Dsynchrony.bind=0.0.0.0 \
  -Dcluster.interfaces=${node_ip} \
  -Dsynchrony.context.path=${SYNCHRONY_CONTEXT_PATH} \
  -Djwt.public.key=\"${jwt_public_key}\" \
  -Dsynchrony.database.username=\"${hibernate_connection_username}\" \
  -Dsynchrony.database.url=\"${hibernate_connection_url}\" \
  -Dsynchrony.service.url=\"${SYNCHRONY_SERVICE_URL},http://${node_ip}:${synchrony_port}${SYNCHRONY_CONTEXT_PATH}\" \
  -Dip.whitelist=${node_ip},127.0.0.1,localhost \
  -Dc3p0.maxPoolSize=${CONFLUENCE_C3P0_MAX_SIZE} \
  ${log4j_configuration_file} \
  synchrony.core \
  sql"

  log "using synchrony_cmd : [${synchrony_cmd}]"
  cat <<EOT > ${confluence_install_dir}/bin/start-synchrony.sh
if [ -f ${confluence_home_dir}/synchrony.pid ] ; then
  kill -9 \$(cat ${confluence_home_dir}/synchrony.pid)
fi
rm -rvf ${confluence_home_dir}/synchrony.pid
mkdir -p ${confluence_home_dir}/logs
cd ${confluence_home_dir}/logs
SYNCHRONY_DATABASE_PASSWORD="${hibernate_connection_password}" JWT_PRIVATE_KEY="${jwt_private_key}" ${synchrony_cmd} >>/dev/null 2>&1 &
synchrony_pid=\$!
echo "\${synchrony_pid}" > ${confluence_home_dir}/synchrony.pid
echo "started synchrony with pid \${synchrony_pid}"
echo "============================================"
echo "${confluence_home_dir}/logs/atlassian-synchrony.log "
echo "============================================"
tail -n 200 ${confluence_home_dir}/logs/atlassian-synchrony.log
EOT
  cat <<EOT > ${confluence_install_dir}/bin/stop-synchrony.sh
if [ -f ${confluence_home_dir}/synchrony.pid ] ; then
  synchrony_pid=\$(cat ${confluence_home_dir}/synchrony.pid)
  echo "killing synchrony with pid \${synchrony_pid}"
  kill -9 \${synchrony_pid}
else
  echo "${confluence_home_dir}/synchrony.pid not found"
fi
EOT
  chmod +x ${confluence_install_dir}/bin/start-synchrony.sh
  chmod +x ${confluence_install_dir}/bin/stop-synchrony.sh
  cp -v ${ATL_CONFLUENCE_SHARED_HOME}/install_synchrony_service.sh ${confluence_install_dir}/bin/install_synchrony_service.sh
  chmod +x ${confluence_install_dir}/bin/install_synchrony_service.sh
  chown -R confluence:confluence "${confluence_install_dir}"
  ${confluence_install_dir}/bin/install_synchrony_service.sh
  ${confluence_install_dir}/bin/install_linux_service.sh -u >/dev/null 2>&1
  log "Synchrony service installed"
}

function wait_until_startup_complete {
  ## wait for confluence to finish starting up, then
  ## delete the node id file at ${ATL_CONFLUENCE_SHARED_HOME}/node.id.${unique_node_id} to let other nodes to continue starting up
  local unique_node_id=`get_unique_id`
  log "waiting for node (${ATL_CONFLUENCE_SHARED_HOME}/node.id.${unique_node_id}) to finish booting confluence..."
  while [ ! -f ${ATL_CONFLUENCE_HOME}/logs/atlassian-confluence.log ] ;
  do
    log "waiting on log file ${ATL_CONFLUENCE_HOME}/logs/atlassian-confluence.log ..."
    log "sleeping for 10 seconds..."
    sleep 10
  done
  tail -f ${ATL_CONFLUENCE_HOME}/logs/atlassian-confluence.log | while read LOGLINE
  do
    [[ "${LOGLINE}" == *"Confluence is ready to serve"* ]] && pkill -P $$ tail
  done
  rm -rfv ${ATL_CONFLUENCE_SHARED_HOME}/node.id.${unique_node_id}
}

function remount_share {
  atl_log remount_share "Remounting shared home [${ATL_CONFLUENCE_SHARED_HOME}] so it's owned by CONFLUENCE"
  local uid=$(id -u confluence)
  local gid=$(id -g confluence)
  umount "${ATL_CONFLUENCE_SHARED_HOME}"
  atl_log remount_share "Temporary share has been unmounted!"
  atl_log remount_share "Permanently mounting [${ATL_CONFLUENCE_SHARED_HOME}] with [uid=${uid}, gid=${gid}] as owner"
  mount_share 1 $uid $gid
}

function prepare_datadisks {
  atl_log prepare_datadisks "Preparing data disks, striping, adding to fstab"
  ./vm-disk-utils-0.1.sh -b "/datadisks" -o "noatime,nodiratime,nodev,noexec,nosuid,nofail,barrier=0" -s
  atl_log prepare_datadisks "Creating symlink from [${ATL_CONFLUENCE_HOME}] to striped disk at [/datadisks/disk1]"
  mkdir -p $(dirname "${ATL_CONFLUENCE_HOME}")
  ln -d -s "/datadisks/disk1" "${ATL_CONFLUENCE_HOME}"
  atl_log prepare_datadisks "Done preparing and configuring data disks"
}

function prepare_install {
  enable_rc_local
  tune_tcp_keepalive_for_azure
  enable_nat
  prepare_share
  download_installer
  preserve_installer
  prepare_server_id_generator
  prepare_jwt_keypair_generator
  hydrate_shared_config
  copy_artefacts
  prepare_password_generator
  install_password_generator
  download_mssql_driver
  prepare_database
  apply_database_dump
}

function install_confluence {
  tune_tcp_keepalive_for_azure
  log "Ready to install CONFLUENCE"
  mount_share
  prepare_datadisks
  prepare_varfile
  prepare_installer
  prepare_fontconfig
  perform_install
  configure_confluence
  remount_share
  log "Done installing CONFLUENCE! Starting..."
  env -i /etc/init.d/confluence start
  wait_until_startup_complete
}

function install_synchrony {
  tune_tcp_keepalive_for_azure
  log "Ready to install Synchrony"
  mount_share
  prepare_varfile
  prepare_installer
  prepare_fontconfig
  perform_install
  install_synchrony_service
  remount_share
  log "Done installing Synchrony! Starting..."
  env -i /etc/init.d/synchrony start
}

install_jq
#$1 is the storage key, $3 is the fqdn of the ip address, $4 is the fqdn of the database server
prepare_env $1 $3 $4

if [ "$2" == "prepare" ]; then
  prepare_install
fi

if [ "$2" == "install" ]; then
  install_confluence
fi

if [ "$2" == "synchrony" ]; then
  install_synchrony
fi

if [ "$2" == "uninstall" ]; then
  if [ "$3" == "--yes-i-want-to-lose-everything" ]; then
    rm -rf "${ATL_CONFLUENCE_INSTALL_DIR}"
    rm -rf "${ATL_CONFLUENCE_HOME}"
    rm /etc/init.d/confluence
    userdel confluence
  fi
fi

