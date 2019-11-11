#! /bin/bash

function error() {
    echo -e "\033[41;36mERROR:\033[0m\e[31m $@\e[0m"
}

function info() {
    echo -e "\033[42;36m\e[37mINFO:\033[0m\e[32m $@\e[0m"
}

function check_ip() {
    IP=$1
    if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        FIELD1=$(echo $IP|cut -d. -f1)
        FIELD2=$(echo $IP|cut -d. -f2)
        FIELD3=$(echo $IP|cut -d. -f3)
        FIELD4=$(echo $IP|cut -d. -f4)
        if [ $FIELD1 -le 255 -a $FIELD2 -le 255 -a $FIELD3 -le 255 -a $FIELD4 -le 255 ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

function getIpmiInfo(){
    info "****** Enter the IPMI username password ip_addr ******"
    echo -n "Enter the IPMI username: "
    read username
    echo -n "Enter the IPMI password: "
    read password1
    echo -n 'Enter the IPMI password again: '
    read password2
    if [ "$password1" != "$password2" ]; then
        error "Password twice enter is not equal, exit..."
        exit 1
    fi
    echo -n "Enter the IPMI ip: "
    read ip_addr
    check_ip $ip_addr
    if [ $? -eq 1 ]; then
        error "Ip addr is illegal, exit..."
        exit 1
    fi
}

function requires_root {
    if [[ $EUID -ne 0 ]]; then
        error "You need root to run the program" 2>&1
        exit 1
    fi
}

function confget() {
    local file=$1
    local option=$2
    local line
    line=$(sed -ne "/^$option[ \t]*=/ p;" $file)
    echo ${line#*=}
}

function generate_post_data()
{
cat <<EOF
{"username": "$username", "password": "$password1", "ip_addr": "$ip_addr", "ssh_port": "$ssh_port", "ssh_password": "$ssh_password", "hostname": "$HOSTNAME"}
EOF
}

function check_port() {
    netstat -tlpn | grep "\b$1\b" 2>/dev/null 1>/dev/null
}

function check_and_set_port() {
    if check_port $ssh_port; then
        let ssh_port=$[ssh_port + 1]
        check_and_set_port
    fi
}

function wait_port_listening() {
    is_port_listening=false
    for ((i=1; i<=$1; i=i+1))
    do
        if check_port $ssh_port; then
            is_port_listening=true
            break
        fi
        sleep 1
    done

    if [ ! is_port_listening ]; then
        # false is 1
        return 1
    else
        # true is 0
        return 0
    fi
}

function make_runc_exec_shell() {
cat << EOF > $CUR_DIR/run.sh
#! /bin/sh

passwd << MYEOF
$ssh_password
$ssh_password
MYEOF

mkdir -p /etc/dropbear
mkdir -p /var/run/dropbear
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbear -F -p $ssh_port
EOF
chmod +x $CUR_DIR/run.sh
}

function prepare_rootfs() {
    ROOFS_DIR=$CUR_DIR/rootfs
    mkdir -p $ROOFS_DIR
    cd $ROOFS_DIR
    zcat $CUR_DIR/initramfs | cpio -id
}

function get_baremetal_agent_uri() {
    local region=$1
    local filter_ip=$2
    local token=$3
    http_resp=`curl -k -s -w "\n%{http_code}" -X GET -H "X-Auth-Token: $token" $region'/misc/bm-agent-url?ip='$filter_ip`
    echo $http_resp
}

function main() {
    info "*********** Register baremetal start ... ************"

    CUR_DIR=$(dirname $(readlink -f "$0"))

    requires_root
    # prepare_rootfs
    getIpmiInfo

    CONFIG_FILE=$CUR_DIR/baremetal_prepare.conf
    HOSTNAME=`hostname | cut -d . -f 1`
    # baremetal_agent_uri=$1
    auth_token=$1
    region_uri=$2
    ssh_password=$3
    ssh_port=2222

    if [ -z $auth_token ]; then
        error "Not found auth token, exit..."
        exit 1
    fi

    baremetal_agent_uri_resp=$(get_baremetal_agent_uri $region_uri $ip_addr $auth_token)
    if [ -z "$baremetal_agent_uri_resp" ]; then
        error "Failed get baremetal agent uri, empty response"
        exit 1
    fi
    baremetal_agent_uri_resp_arr=(${baremetal_agent_uri_resp[@]})
    resp_code=${baremetal_agent_uri_resp_arr[${#baremetal_agent_uri_resp_arr[@]}-1]}
    if (( $resp_code != 200 )); then
        error "Failed get baremetal agent uri, $baremetal_agent_uri_resp"
        exit 1
    fi
    baremetal_agent_uri=${baremetal_agent_uri_resp_arr[0]}
    info "baremetal agent: $baremetal_agent_uri"

    if [ -z $ssh_password ]; then
        ssh_password="yunion@123"
    fi

    check_and_set_port
    make_runc_exec_shell

    # RUNC_CMD=$CUR_DIR/runc
    # linux_first_kernel_version=`uname -r | cut -d. -f1`
    # if (( linux_first_kernel_version == 2 )); then
    #     # kernel version 2.x
    #     RUNC_CMD=$CUR_DIR/runc_2
    # fi
    RUNC_CMD=$CUR_DIR/runns

    cd $CUR_DIR
    $RUNC_CMD kill yunion_baremetal_prepare
    $RUNC_CMD run yunion_baremetal_prepare

    # wait ssh port in use
    if ! wait_port_listening 60 ; then
        error "dropbear ssh server not started"
        exit_clean
        exit 1
    fi


    resp=`curl -k -s -w "\n%{http_code}" -X POST \
    $baremetal_agent_uri'/baremetals/register-baremetal' \
    -H 'Content-Type: application/json' -H "X-Auth-Token: $auth_token" \
    -d "$(generate_post_data)"`
    # resp format: "{http baody content} http_code"
    if [ -z "$resp" ]; then
        error "Request regiester faild, empty response"
        exit_clean
        exit 1
    fi

    # format resp as array
    resp_arr=(${resp[@]})
    # get response code
    http_code=${resp_arr[${#resp_arr[@]}-1]}
    # http_body=${resp_arr[@]::${#resp_arr[@]}-1}

    if (( $http_code != "200" )); then
        error "$resp"
        exit_clean
        error "Http register baremetal error, exit..."
        exit 1
    fi

    info "Prepare SUCCESS waiting register, It takes a few minutes..."
    sleep 600
    exit_clean
}

#clean runc process
function exit_clean() {
    $RUNC_CMD kill yunion_baremetal_prepare
}

main $@