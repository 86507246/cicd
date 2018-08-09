#/bin/bash

MAX_CORES=10
RESULTS_FILE="results.csv"
LOG_FILE="results.log"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"

vms=(
    'vm=(Standard_L4s 4 EastUS2)'
    'vm=(Standard_L8s 8 WestUS)'
    'vm=(Standard_E8s_v3 8 EastUS)'
    'vm=(Standard_F4s 4 CentralUS)'
    'vm=(Standard_F8s 8 AustraliaCentral)'
    'vm=(Standard_D8s_v3 8 AustraliaCentral2)'
    'vm=(Standard_DS4_v2 8 AustraliaSouthEast)'
)

disks=(
    "255"
    "511"
    "1023"
)

caches=(
    "None"
    "ReadOnly"
    "ReadWrite"
)

function do_log {
  local scope=$1
  local msg=$2
  echo "[${scope}]: ${msg}" >> "${LOG_FILE}"
}

function log {
  do_log "${FUNCNAME[1]}" "$1"
}

function error {
  do_log "${FUNCNAME[1]}" "$1"
  exit 3
}

function gen_pass() {
    openssl rand -base64 32
}

function get_ssh_key() {
    cat "${SSH_KEY}"
}

function prep_parameters() {
    local vm="${1}"
    local disk="${2}"
    local cache="${3}"

    log "Preparing parameters for [vm=${vm}, disk=${disk}, cache=${cache}]"

    cat <<EOT > "bitbucket/azuredeploy.parameters.local.json"
{
  "parameters": {
    "adminUser": {
      "value": "bbsadmin"
    },
    "adminPass": {
      "value": "$(gen_pass)"
    },
    "sshKey": {
      "value": "$(get_ssh_key)"
    },
    "diskSize": {
        "value": ${disk}
    },
    "jumpboxSize": {
        "value": "${vm}"
    },
    "diskCaching": {
        "value": "${cache}"
    }
  }
}
EOT
}

function has_results() {
    if [ -f ".createDeployResult" ]; then
        return 0; # 0 == true
    else
        return 1; # 1 == false
    fi
}

function has_log() {
    if [ -f "${LOG_FILE}" ]; then
        return 0; # 0 == true
    else
        return 1; # 1 == false
    fi
}

function read_results() {
    cat ".createDeployResult"
}


function clean_results() {
    log "Cleaning up previous deployment output"
    if has_results; then
        rm ".createDeployResult"
    fi
}

function clean_log() {
    if has_log; then
        rm "${LOG_FILE}"
    fi
}

function process_results() {
    local vm="${1}"
    local disk="${2}"
    local cache="${cache}"

    local label="${vm}-${disk}-${cache}"

    log "Processing results for test [vm=${vm}, disk=${disk}, cache=${cache}]. Assigned [label=${label}]"

    if has_results; then
        local stats=`read_results | jq '.properties.outputs.stats.value' -r`
        echo "${stats/jumpbox/$label}" >> "${RESULTS_FILE}"
    else
        log "Couldn't process results - no result file. Probably deployment has failed."
    fi
}

function update_location() {
    local location="${1}"

    log "Setting [location=${location}]"

    echo "${location}" > ".location"
}

function start() {
    if [ "${DRY_RUN}" != "y" ]; then
        log "Running the deployment..."
        npm start
        log "Deployment has been completed!"
    else
        log "Dry run! Skipping the deployment."
    fi
}

function stop() {
    if [ "${DRY_RUN}" != "y" ]; then
        log "Stopping the deployment..."
        npm stop
        log "Deployment has been stopped"
    else
        log "Dry run! Skipping the cleanup."
    fi
}

function do_test() {
    local vm="${1}"
    local location="${2}"
    local disk="${3}"
    local cache="${4}"

    log "Testing [vm=${vm}, location=${location}, disk=${disk}, cache=${cache}]"

    clean_results
    update_location "${location}"
    prep_parameters "${vm}" "${disk}" "${cache}"
    start
    process_results "${vm}" "${disk}" "${cache}"

    log "Done testing [vm=${vm}, location=${location}, disk=${disk}, cache=${cache}]"
}

function test() {
    log "Starting performance testing..."

    for cache in ${caches[@]}; do
        for disk in ${disks[@]}; do
            for vm in "${vms[@]}"; do
                eval $vm

                local vm_name="${vm[0]}"
                local vm_cores="${vm[1]}"
                local vm_location="${vm[2]}"

                log "Ready to test [vm=${vm_name}, cores=${vm_cores}, location=${vm_location}]"

                if [ "${vm_cores}" -lt "${MAX_CORES}" ]; then
                    do_test "${vm_name}" "${vm_location}" "${disk}" "${cache}"
                else
                    log "Skipping test [vm=${vm_name}] it has too many [cores=${vm_cores}]. Configured maximum amount of [cores=${MAX_CORES}]"
                fi  
            done
        done
    done

    log "Performance test has been completed, cleaning up..."
    stop
    log "Cleanup has been completed!"
}

clean_log
test
