#/bin/bash

MAX_CORES=100
RESULTS_FILE="results.csv"

vms=(
    'vm=(Standard_B1s 1 AustraliaSouthEast)'
    'vm=(Standard_B1ms 1 AustraliaSouthEast)'
    'vm=(Standard_B2s 2 AustraliaSouthEast)'
    'vm=(Standard_B2ms 2 AustraliaSouthEast)'
    'vm=(Standard_B4ms 4 AustraliaSouthEast)'
    'vm=(Standard_B8ms 8 AustraliaSouthEast)'
    'vm=(Standard_D2s_v3 2 AustraliaSouthEast)'
    'vm=(Standard_D4s_v3 4 AustraliaSouthEast)'
    'vm=(Standard_D8s_v3 8 AustraliaSouthEast)'
    'vm=(Standard_D16s_v3 16 AustraliaSouthEast)'
    'vm=(Standard_D32s_v3 32 AustraliaSouthEast)'
    'vm=(Standard_D64s_v3 64 AustraliaSouthEast)'
    'vm=(Standard_D2_v3 2 AustraliaSouthEast)'
    'vm=(Standard_D4_v3 4 AustraliaSouthEast)'
    'vm=(Standard_D8_v3 8 AustraliaSouthEast)'
    'vm=(Standard_D16_v3 16 AustraliaSouthEast)'
    'vm=(Standard_D32_v3 32 AustraliaSouthEast)'
    'vm=(Standard_D64_v3 64 AustraliaSouthEast)'
    'vm=(Standard_DS1_v2 1 AustraliaSouthEast)'
    'vm=(Standard_DS2_v2 2 AustraliaSouthEast)'
    'vm=(Standard_DS3_v2 4 AustraliaSouthEast)'
    'vm=(Standard_DS4_v2 8 AustraliaSouthEast)'
    'vm=(Standard_DS5_v2 16 AustraliaSouthEast)'
    'vm=(Standard_D1_v2 1 AustraliaSouthEast)'
    'vm=(Standard_D2_v2 2 AustraliaSouthEast)'
    'vm=(Standard_D3_v2 4 AustraliaSouthEast)'
    'vm=(Standard_D4_v2 8 AustraliaSouthEast)'
    'vm=(Standard_D5_v2 16 AustraliaSouthEast)'
    'vm=(Standard_A1_v2 1 AustraliaSouthEast)'
    'vm=(Standard_A2_v2 2 AustraliaSouthEast)'
    'vm=(Standard_A4_v2 4 AustraliaSouthEast)'
    'vm=(Standard_A8_v2 8 AustraliaSouthEast)'
    'vm=(Standard_A2m_v2 2 AustraliaSouthEast)'
    'vm=(Standard_A4m_v2 4 AustraliaSouthEast)'
    'vm=(Standard_A8m_v2 8 AustraliaSouthEast)'
    'vm=(Standard_F2s_v2 2 AustraliaSouthEast)'
    'vm=(Standard_F4s_v2 4 AustraliaSouthEast)'
    'vm=(Standard_F8s_v2 8 AustraliaSouthEast)'
    'vm=(Standard_F16s_v2 16 AustraliaSouthEast)'
    'vm=(Standard_F32s_v2 32 AustraliaSouthEast)'
    'vm=(Standard_F64s_v2 64 AustraliaSouthEast)'
    'vm=(Standard_F72s_v2 72 AustraliaSouthEast)'
    'vm=(Standard_F1s 1 AustraliaSouthEast)'
    'vm=(Standard_F2s 2 AustraliaSouthEast)'
    'vm=(Standard_F4s 4 AustraliaSouthEast)'
    'vm=(Standard_F8s 8 AustraliaSouthEast)'
    'vm=(Standard_F16s 16 AustraliaSouthEast)'
    'vm=(Standard_F1 1 AustraliaSouthEast)'
    'vm=(Standard_F2 2 AustraliaSouthEast)'
    'vm=(Standard_F4 4 AustraliaSouthEast)'
    'vm=(Standard_F8 8 AustraliaSouthEast)'
    'vm=(Standard_F16 16 AustraliaSouthEast)'
    'vm=(Standard_E2s_v3 2 AustraliaSouthEast)'
    'vm=(Standard_E4s_v3 4 AustraliaSouthEast)'
    'vm=(Standard_E8s_v3 8 AustraliaSouthEast)'
    'vm=(Standard_E16s_v3 16 AustraliaSouthEast)'
    'vm=(Standard_E32s_v3 32 AustraliaSouthEast)'
    'vm=(Standard_E64s_v3 64 AustraliaSouthEast)'
    'vm=(Standard_E64is_v3 64 AustraliaSouthEast)'
    'vm=(Standard_E2_v3 2 AustraliaSouthEast)'
    'vm=(Standard_E4_v3 4 AustraliaSouthEast)'
    'vm=(Standard_E8_v3 8 AustraliaSouthEast)'
    'vm=(Standard_E16_v3 16 AustraliaSouthEast)'
    'vm=(Standard_E32_v3 32 AustraliaSouthEast)'
    'vm=(Standard_E64_v3 64 AustraliaSouthEast)'
    'vm=(Standard_E64i_v3 64 AustraliaSouthEast)'
    'vm=(Standard_M8ms 8 AustraliaSouthEast)'
    'vm=(Standard_M16ms 16 AustraliaSouthEast)'
    'vm=(Standard_M32ts 32 AustraliaSouthEast)'
    'vm=(Standard_M32ls 32 AustraliaSouthEast)'
    'vm=(Standard_M32ms 32 AustraliaSouthEast)'
    'vm=(Standard_M64s 64 AustraliaSouthEast)'
    'vm=(Standard_M64ls 64 AustraliaSouthEast)'
    'vm=(Standard_M64ms 64 AustraliaSouthEast)'
    'vm=(Standard_M128s 128 AustraliaSouthEast)'
    'vm=(Standard_M128ms 128 AustraliaSouthEast)'
    'vm=(Standard_M64 64 AustraliaSouthEast)'
    'vm=(Standard_M64m 64 AustraliaSouthEast)'
    'vm=(Standard_M128 128 AustraliaSouthEast)'
    'vm=(Standard_M128m 128 AustraliaSouthEast)'
    'vm=(Standard_GS1 2 WestUS2)'
    'vm=(Standard_GS2 4 WestUS2)'
    'vm=(Standard_GS3 8 WestUS2)'
    'vm=(Standard_GS4 16 WestUS2)'
    'vm=(Standard_GS5 32 WestUS2)'
    'vm=(Standard_G1 2 WestUS2)'
    'vm=(Standard_G2 4 WestUS2)'
    'vm=(Standard_G3 8) WestUS2'
    'vm=(Standard_G4 16 WestUS2)'
    'vm=(Standard_G5 32 WestUS2)'
    'vm=(Standard_DS11_v2 2 AustraliaSouthEast)'
    'vm=(Standard_DS12_v2 4 AustraliaSouthEast)'
    'vm=(Standard_DS13_v2 8 AustraliaSouthEast)'
    'vm=(Standard_DS14_v2 16 AustraliaSouthEast)'
    'vm=(Standard_DS15_v2 20 AustraliaSouthEast)'
    'vm=(Standard_D11_v2 2 AustraliaSouthEast)'
    'vm=(Standard_D12_v2 4 AustraliaSouthEast)'
    'vm=(Standard_D13_v2 8 AustraliaSouthEast)'
    'vm=(Standard_D14_v2 16 AustraliaSouthEast)'
    'vm=(Standard_D15_v2 20 AustraliaSouthEast)'
)

storage_vms=( 
    'vm=(Standard_L4s 4)'
    'vm=(Standard_L8s 8)'
    'vm=(Standard_L16s 16)'
    'vm=(Standard_L32s 32)'
)

disks=(
    "31"
    "63"
    "127"
    "255"
    "511"
    "1023"
    "2047"
    "4095"
)

caches=(
    "None"
    "ReadOnly"
    "ReadWrite"
)

function prep_parameters() {
    local vm="${1}"
    local disk="${2}"
    local cache="${3}"
    cat <<EOT > "bitbucket/azuredeploy.parameters.local.json"
{
  "parameters": {
    "adminUser": {
      "value": "bbsadmin"
    },
    "adminPass": {
      "value": "k[MlmkcG$$['v-3g1NPL|y0UCSHV"
    },
    "sshKey": {
      "value": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3CNLotlCeajpQygaiVLgkdFqqEdzbbpi72JhgA8baWv8flu3mEXPq4sbUrlv04tP0Fgi5EAfgFbwWmN/23pQR0t1lEU7TB9uU+IrhhKHuCoDikkqa//gxnAYxrY3ze6p+Ib0FTSpIrIsY1D2t1z6S/33kBz59Iz5tX6XtijGUQj5lyttfek8O2pZbGL5qHHJzyl67JfCOB8eAWhVBbL96SJgK3XlZE1rEwlA0CPa+mNLSdTd9jxBpml42RR4JEMJOtalzRXLCKubSWjfDqK5XPIhJ2vhWI2c2qgoVe/tkj6OWyXxCRImjhhSX1AMSuYKdUsimsPnOziIWm2aoE4jD aermolenko@CLI-24467"
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

function read_results() {
    cat ".createDeployResult"
}

function clean_results() {
    if has_results; then
        rm ".createDeployResult"
    fi
}

function process_results() {
    local vm="${1}"
    local disk="${2}"
    local cache="${cache}"

    local label="${vm}-${disk}-${cache}"

    if has_results; then
        local stats=`read_results | jq '.properties.outputs.stats.value' -r`
        echo "${stats/jumpbox/$label}" >> "${RESULTS_FILE}"
    else
        echo "Couldn't process results - no result file. Probably deployment has failed."
    fi
    
}

function do_test() {
    local vm="${1}"
    local disk="${2}"
    local cache="${cache}"

    clean_results
    prep_parameters "${vm}" "${disk}" "${cache}"
    npm start
    process_results "${vm}" "${disk}" "${cache}"
}

function test() {
    for vm in "${storage_vms[@]}"; do
        eval $vm

        local vm_name="${vm[0]}"
        local vm_cores="${vm[1]}"

        if [ "${vm_cores}" -lt "${MAX_CORES}" ]; then
            for disk in ${disks[@]}; do
                for cache in ${caches[@]}; do
                    do_test "${vm_name}" "${disk}" "${cache}"
                done
            done
        fi    
    done

    npm stop
}

test
