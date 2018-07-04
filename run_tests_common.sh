#!/usr/bin/env bash
# Copyright 2015, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o pipefail
set -euov

BINDEP_FILE=${BINDEP_FILE:-bindep.txt}

source /etc/os-release || source /usr/lib/os-release

case "${ID,,}" in
    centos)
        sudo yum install -y python-devel redhat-lsb-core
        ;;
    ubuntu|debian)
        sudo apt-get update && sudo apt-get install -y python-dev lsb-release
        ;;
    *)
        echo "Unsupported distribution: ${ID,,}"
        exit 1
esac

# Install pip
if ! which pip &>/dev/null; then
    curl --silent --show-error --retry 5 \
        https://bootstrap.pypa.io/3.2/get-pip.py | sudo python2.7
fi

# Install bindep and tox
sudo pip install 'bindep>=2.4.0' tox

# CentOS 7 requires two additional packages:
#   redhat-lsb-core - for bindep profile support
#   epel-release    - required to install python-ndg_httpsclient/python2-pyasn1
if [[ ${ID,,} == "centos" ]]; then
    sudo yum -y install redhat-lsb-core epel-release
fi

# Get a list of packages to install with bindep. If packages need to be
# installed, bindep exits with an exit code of 1.
BINDEP_PKGS=$(bindep -b -f ${BINDEP_FILE} test || true)
echo "Packages to install: ${BINDEP_PKGS}"

# Install OS packages using bindep
if [[ ${#BINDEP_PKGS} > 0 ]]; then
    case "${ID,,}" in
        centos)
            sudo yum install -y $BINDEP_PKGS
            ;;
        ubuntu|debian)
            sudo apt-get update
            DEBIAN_FRONTEND=noninteractive \
                sudo apt-get -q --option "Dpkg::Options::=--force-confold" \
                --assume-yes install $BINDEP_PKGS
            ;;
    esac
fi

# Get envlist in a $env1,$env2,...,$envn format
toxenvs="$(tox -l | tr '\n' ',' | sed 's/,$//')"

# Execute all $toxenvs or only a specific one
tox -e "${1:-$toxenvs}"
