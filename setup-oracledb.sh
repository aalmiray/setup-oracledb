#!/bin/bash
# Since: January, 2023
# Author: aalmiray
#
# Copyright 2023 Andres Almiray
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

ORADATA="/opt/oracle/oradata"
DEFAULT_CONTAINER_NAME="oracledb"
DEFAULT_HEALTH_SCRIPT="/opt/oracle/checkDBStatus.sh"

HEALTH_SCRIPT="${DEFAULT_HEALTH_SCRIPT}"
HEALTH_MAX_RETRIES=20
HEALTH_INTERVAL=10

DOCKER_ARGS=""
DOCKER_IMAGE=""
CONTAINER_NAME=""
VALIDATION="OK"

###############################################################################
echo "::group::🔍 Verifying inputs"

# IMAGE
echo "✅ image set to ${SETUP_IMAGE}"
DOCKER_IMAGE="${SETUP_IMAGE}"

# PORT
echo "✅ port set to ${SETUP_PORT}"
DOCKER_ARGS="-p 1521:${SETUP_PORT}"

# CONTAINER_NAME
if [ -n "${SETUP_CONTAINER_NAME}" ]; then
    echo "✅ container name set to ${SETUP_CONTAINER_NAME}"
    CONTAINER_NAME=${SETUP_CONTAINER_NAME}
else
    echo "☑️️ container name set to ${DEFAULT_CONTAINER_NAME}"
    CONTAINER_NAME=${DEFAULT_CONTAINER_NAME}
fi
DOCKER_ARGS="${DOCKER_ARGS} --name ${CONTAINER_NAME}"

# HEALTH_SCRIPT
if [ -n "${SETUP_HEALTH_SCRIPT}" ]; then
    echo "✅ healthcheck script set to ${SETUP_HEALTH_SCRIPT}"
    HEALTH_SCRIPT=${SETUP_HEALTH_SCRIPT}
else
    echo "☑️️ healthcheck script set to ${DEFAULT_HEALTH_SCRIPT}"
    HEALTH_SCRIPT=${DEFAULT_HEALTH_SCRIPT}
fi

# HEALTH_MAX_RETRIES
if [ -n "${SETUP_HEALTH_MAX_RETRIES}" ]; then
    echo "✅ health max retries set to ${SETUP_HEALTH_MAX_RETRIES}"
    HEALTH_MAX_RETRIES=$SETUP_HEALTH_MAX_RETRIES
else
    echo "☑️️ health max retries set to 10"
    HEALTH_MAX_RETRIES=10
fi

# HEALTH_INTERVAL
if [ -n "${SETUP_HEALTH_INTERVAL}" ]; then
    echo "✅ health interval set to ${SETUP_HEALTH_INTERVAL}"
    HEALTH_INTERVAL=$SETUP_HEALTH_INTERVAL
else
    echo "☑️️ health interval set to 10"
    HEALTH_INTERVAL=10
fi

# VOLUME
if [ -n "${SETUP_VOLUME}" ]; then
    echo "✅ volume set to ${SETUP_VOLUME} mapped to ${ORADATA}"
    DOCKER_ARGS="${DOCKER_ARGS} -v ${SETUP_VOLUME}:${ORADATA}"
    chmod 777 ${SETUP_VOLUME}
fi

# ORACLE_SID
if [ -n "${ORACLE_SID}" ]; then
    echo "✅ ORACLE_SID is set"
    DOCKER_ARGS="${DOCKER_ARGS} -e ORACLE_SID=${ORACLE_SID}"
fi

# ORACLE_PDB
if [ -n "${ORACLE_PDB}" ]; then
    echo "✅ ORACLE_PDB is set"
    DOCKER_ARGS="${DOCKER_ARGS} -e ORACLE_PDB=${ORACLE_PDB}"
fi

# ORACLE_PWD
if [ -n "${ORACLE_PWD}" ]; then
    echo "✅ ORACLE_PWD is set"
    DOCKER_ARGS="${DOCKER_ARGS} -e ORACLE_PWD=${ORACLE_PWD}"
fi

# INIT_SGA_SIZE
if [ -n "${INIT_SGA_SIZE}" ]; then
    echo "✅ INIT_SGA_SIZE is set to ${INIT_SGA_SIZE}"
    DOCKER_ARGS="${DOCKER_ARGS} -e INIT_SGA_SIZE=${INIT_SGA_SIZE}"
fi

# INIT_PGA_SIZE
if [ -n "${INIT_PGA_SIZE}" ]; then
    echo "✅ INIT_PGA_SIZE is set to ${INIT_PGA_SIZE}"
    DOCKER_ARGS="${DOCKER_ARGS} -e INIT_PGA_SIZE=${INIT_PGA_SIZE}"
fi

# ORACLE_EDITION
if [ -n "${ORACLE_EDITION}" ]; then
    echo "✅ ORACLE_EDITION is set to ${ORACLE_EDITION}"
    DOCKER_ARGS="${DOCKER_ARGS} -e ORACLE_EDITION=${ORACLE_EDITION}"
fi

# ORACLE_CHARACTERSET
if [ -n "${ORACLE_CHARACTERSET}" ]; then
    echo "✅ ORACLE_CHARACTERSET is set to ${ORACLE_CHARACTERSET}"
    DOCKER_ARGS="${DOCKER_ARGS} -e ORACLE_CHARACTERSET=${ORACLE_CHARACTERSET}"
fi

# ENABLE_ARCHIVELOG
if [ -n "${ENABLE_ARCHIVELOG}" ]; then
    echo "✅ ENABLE_ARCHIVELOG is set"
    DOCKER_ARGS="${DOCKER_ARGS} -e ENABLE_ARCHIVELOG=${ENABLE_ARCHIVELOG}"
fi

# SETUP_SCRIPTS
if [ -n "${SETUP_SETUP_SCRIPTS}" ]; then
    echo "✅ setup scripts from ${SETUP_SETUP_SCRIPTS}"
    DOCKER_ARGS="${DOCKER_ARGS} -v ${SETUP_SETUP_SCRIPTS}:/opt/oracle/scripts/setup"
fi

# STARTUP_SCRIPTS
if [ -n "${SETUP_STARTUP_SCRIPTS}" ]; then
    echo "✅ startup scripts from ${SETUP_STARTUP_SCRIPTS}"
    DOCKER_ARGS="${DOCKER_ARGS} -v ${SETUP_STARTUP_SCRIPTS}:/opt/oracle/scripts/startup"
fi

if [ -n "${VALIDATION}" ]; then
    echo "✅ All inputs are valid"
else
    echo "❌ Validation failed"
fi
echo "::endgroup::"
###############################################################################

if [ -z "${VALIDATION}" ]; then
    exit 1;
fi

###############################################################################
echo "::group::🐳 Running Docker"
CMD="docker run -d ${DOCKER_ARGS} ${DOCKER_IMAGE}"
echo $CMD
OUTPUT=$($CMD)
echo "::endgroup::"
###############################################################################

###############################################################################
echo "::group::⏰ Waiting for database to be ready"
COUNTER=0
DB_IS_UP=1
EXIT_VALUE=0

while [ $COUNTER -lt $HEALTH_MAX_RETRIES ]
do
    COUNTER=$(( $COUNTER + 1 ))
    echo "  - try #$COUNTER"
    sleep $HEALTH_INTERVAL
    DB_IS_UP=$(docker exec "${CONTAINER_NAME}" "${HEALTH_SCRIPT}" && echo "yes" || echo "no")
    CUSTOM_SCRIPT=$(echo "${HEALTH_SCRIPT}" | grep -Eq "^.*healthcheck.sh$" && echo "false" || echo "true")
    if [ "${CUSTOM_SCRIPT}" = "true" ]; then
        # output may contain multiple lines starting with 'The Oracle base remains unchanged with value /opt/oracle'
        DB_IS_UP=$(echo "${DB_IS_UP}" | tr "\n" "\;")
        DB_IS_UP=$(echo "${DB_IS_UP}" | cut -d ";" -f 2)
    fi
    if [ "${DB_IS_UP}" = "yes" ]; then
        break
    fi
done

if [ "${DB_IS_UP}" = "yes" ]; then
    echo "✅ Database is ready!"
else
    echo "❌ Database failed to start on time"
    EXIT_VALUE=1
fi

echo "::endgroup::"
###############################################################################
exit $EXIT_VALUE
