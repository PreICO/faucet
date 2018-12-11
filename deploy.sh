#!/usr/bin/env sh

SERVICE=faucet

[ ! -z ${FAUCET_USER} ] || FAUCET_USER=${SERVICE}d
[ ! -z ${FAUCET_HOME} ] || FAUCET_HOME=/usr/local/${SERVICE}d
[ ! -z ${FAUCET_PORT} ] || FAUCET_PORT=8070
[ ! -z ${FAUCET_DOCKER_HOST} ] || FAUCET_DOCKER_HOST=unix:///var/run/docker.sock
[ ! -z ${FAUCET_DATABASE_ENV} ] || FAUCET_DATABASE_ENV=production
[ ! -z ${FAUCET_DATABASE_SCHEME} ] || FAUCET_DATABASE_SCHEME=mysql
[ ! -z ${FAUCET_DATABASE_HOST} ] || FAUCET_DATABASE_HOST=faucet-db
[ ! -z ${FAUCET_DATABASE_PORT} ] || FAUCET_DATABASE_PORT=3306
[ ! -z ${FAUCET_DATABASE_USER} ] || FAUCET_DATABASE_USER=faucet
[ ! -z ${FAUCET_DATABASE_DATABASE} ] || FAUCET_DATABASE_DATABASE=faucet
[ ! -z ${FAUCET_DATABASE_URL} ] || FAUCET_DATABASE_URL=${FAUCET_DATABASE_SCHEME}://${FAUCET_DATABASE_USER}:${FAUCET_DATABASE_PASSWORD}@${FAUCET_DATABASE_HOST}:${FAUCET_DATABASE_PORT}/${FAUCET_DATABASE_DATABASE}
[ ! -z ${FAUCET_TS_DATABASE_URL} ] || FAUCET_TS_DATABASE_URL=http://faucet-ts-db:8086
[ ! -z ${FAUCET_JUSSI_URL} ] || FAUCET_JUSSI_URL=https://a.earthshare.network
[ ! -z ${FAUCET_ADDRESS_PREFIX} ] || FAUCET_ADDRESS_PREFIX=ESH
[ ! -z ${FAUCET_CHAIN_ID} ] || FAUCET_CHAIN_ID=de8b3f085c312bc871ca3bd5f6efa0f09c4d428a4f7e35354f63a0c403e70b92
[ ! -z ${FAUCET_DELEGATOR_USER} ] || FAUCET_DELEGATOR_USER=faucet
[ ! -z ${FAUCET_CREATE_ACCOUNT_FEE} ] || FAUCET_CREATE_ACCOUNT_FEE="0.030 ESH"
[ ! -z ${FAUCET_CREATE_ACCOUNT_DELEGATION} ] || FAUCET_CREATE_ACCOUNT_DELEGATION="1.000000 VESTS"
[ ! -z ${FAUCET_CONVEYOR_USER} ] || FAUCET_CONVEYOR_USER=faucet
[ ! -z ${FAUCET_CREATE_USER_URL} ] || FAUCET_CREATE_USER_URL=https://earthshare.network/api/create_user
[ ! -z ${FAUCET_REDIRECT_URL} ] || FAUCET_REDIRECT_URL=https://earthshare.network/login.html#account={{username}}
[ ! -z ${FAUCET_GOOGLE_AUTHORIZED_DOMAINS} ] || FAUCET_GOOGLE_AUTHORIZED_DOMAINS=f.earthshare.network
[ ! -z ${FAUCET_REACT_DISABLE_ACCOUNT_CREATION} ] || FAUCET_REACT_DISABLE_ACCOUNT_CREATION=false

WORKTREE=`dirname \`realpath ${0}\``
SERVICE_REPO=${SUDO_USER}/${PROJECT}_${SERVICE}
STAGE0=${SERVICE_REPO}_stage0
FAUCET_GIT_REV=`cd ${WORKTREE} && git rev-parse HEAD`
STAGE1=${SERVICE_REPO}:${FAUCET_GIT_REV}
STAGE_LATEST=${SERVICE_REPO}:latest
DIRTY=`cd ${WORKTREE} && git status -s`

mkdir -p \
    ${WORKTREE}/node_modules \
    ${WORKTREE}/admin/node_modules \
    ${WORKTREE}/admin/build && \
chown \
    -R \
    ${SUDO_UID}:${SUDO_GID} \
    ${WORKTREE}/node_modules \
    ${WORKTREE}/admin/node_modules \
    ${WORKTREE}/admin/build && \
([ -z "${DIRTY}" ] && buildah inspect ${STAGE1} > /dev/null 2> /dev/null || \
 (buildah inspect ${STAGE0} > /dev/null 2> /dev/null || \
  buildah from \
      --name ${STAGE0} \
      node:8.7-stretch) && \
 buildah config \
     -u root \
     --workingdir ${WORKTREE} \
     ${STAGE0} && \
 buildah run \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "apt update && \
             apt upgrade -y" && \
 buildah run \
     --user ${SUDO_UID}:${SUDO_GID} \
     -v ${WORKTREE}/package.json:/usr/src/${SERVICE}/package.json:ro \
     -v ${WORKTREE}/yarn.lock:/usr/src/${SERVICE}/yarn.lock:ro \
     -v ${WORKTREE}/node_modules:/usr/src/${SERVICE}/node_modules \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "cd /usr/src/${SERVICE} && \
             NODE_ENV=development \
             yarn install \
                 --non-interactive \
                 --pure-lockfile" && \
 buildah run \
     --user ${SUDO_UID}:${SUDO_GID} \
     -v ${WORKTREE}:/usr/src/${SERVICE}:ro \
     -v ${WORKTREE}/public/js:/usr/src/${SERVICE}/public/js \
     -v ${WORKTREE}/public/css:/usr/src/${SERVICE}/public/css \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "cd /usr/src/${SERVICE} && \
             NODE_ENV=production yarn run build" && \
 buildah run \
     --user ${SUDO_UID}:${SUDO_GID} \
     -v ${WORKTREE}/package.json:/usr/src/${SERVICE}/package.json:ro \
     -v ${WORKTREE}/yarn.lock:/usr/src/${SERVICE}/yarn.lock:ro \
     -v ${WORKTREE}/admin/package.json:/usr/src/${SERVICE}/admin/package.json:ro \
     -v ${WORKTREE}/admin/yarn.lock:/usr/src/${SERVICE}/admin/yarn.lock:ro \
     -v ${WORKTREE}/admin/node_modules:/usr/src/${SERVICE}/admin/node_modules \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "cd /usr/src/${SERVICE}/admin && \
             NODE_ENV=development \
             yarn install \
                 --non-interactive \
                 --pure-lockfile" && \
 buildah run \
     --user ${SUDO_UID}:${SUDO_GID} \
     -v ${WORKTREE}:/usr/src/${SERVICE}:ro \
     -v ${WORKTREE}/admin/build:/usr/src/${SERVICE}/admin/build \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "cd /usr/src/${SERVICE}/admin && \
             rm -rf ./build/* && \
             NODE_ENV=production \
             REACT_APP_GOOGLE_CLIENT_ID=${FAUCET_GOOGLE_CLIENT_ID} \
             REACT_APP_SERVER_ADDRESS=/admin \
             yarn run build" && \
 buildah run \
     -v ${WORKTREE}:/usr/src/${SERVICE}:ro \
     ${STAGE0} \
     /usr/bin/env \
         -u USER \
         -u HOME \
         sh -c -- \
            "adduser \
                 --system \
                 --home ${FAUCET_HOME} \
                 --shell /bin/bash \
                 --group \
                 --disabled-password \
                 ${FAUCET_USER} && \
             rm -rf ${FAUCET_HOME} && \
             cp \
                 -PRT \
                 /usr/src/${SERVICE} \
                 ${FAUCET_HOME} && \
             cp \
                 -PRT \
                 /usr/src/${SERVICE}/admin/build \
                 ${FAUCET_HOME}/public/admin && \
             rm -rf ${FAUCET_HOME}/admin/build" && \
 buildah config \
     -e USER=${FAUCET_USER} \
     -e HOME=${FAUCET_HOME} \
     -e PORT=${FAUCET_PORT} \
     -e NODE_ENV=production \
     -e DATABASE_NAME=${FAUCET_DATABASE_ENV} \
     -e DATABASE_URL=${FAUCET_DATABASE_URL} \
     -e INFLUXDB_URL=${FAUCET_TS_DATABASE_URL} \
     -e STEEMJS_URL=${FAUCET_JUSSI_URL} \
     -e ADDRESS_PREFIX=${FAUCET_ADDRESS_PREFIX} \
     -e CHAIN_ID=${FAUCET_CHAIN_ID} \
     -e RECAPTCHA_SITE_KEY=${FAUCET_RECAPTCHA_KEY} \
     -e RECAPTCHA_SECRET=${FAUCET_RECAPTCHA_SECRET} \
     -e SENDGRID_API_KEY=${FAUCET_SENDGRID_KEY} \
     -e JWT_SECRET=${FAUCET_JWT_SECRET} \
     -e TWILIO_ACCOUNT_SID=${FAUCET_TWILIO_ACCOUNT_SID} \
     -e TWILIO_SERVICE_SID=${FAUCET_TWILIO_SERVICE_SID} \
     -e TWILIO_AUTH_TOKEN=${FAUCET_TWILIO_SECRET} \
     -e DELEGATOR_USERNAME=${FAUCET_DELEGATOR_USER} \
     -e DELEGATOR_ACTIVE_WIF=${FAUCET_DELEGATOR_ACTIVE_SECRET} \
     -e CREATE_ACCOUNT_FEE="${FAUCET_CREATE_ACCOUNT_FEE}" \
     -e CREATE_ACCOUNT_DELEGATION="${FAUCET_CREATE_ACCOUNT_DELEGATION}" \
     -e CONVEYOR_USERNAME=${FAUCET_CONVEYOR_USER} \
     -e CONVEYOR_POSTING_WIF=${FAUCET_CONVEYOR_POSTING_SECRET} \
     -e CREATE_USER_URL=${FAUCET_CREATE_USER_URL} \
     -e CREATE_USER_SECRET=${FAUCET_CREATE_USER_SECRET} \
     -e DEFAULT_REDIRECT_URI=${FAUCET_REDIRECT_URL} \
     -e GOOGLE_SITE_VERIFICATION=${FAUCET_GOOGLE_SITE_VERIFICATION} \
     -e GOOGLE_CLIENT_ID=${FAUCET_GOOGLE_CLIENT_ID} \
     -e GOOGLE_AUTHORIZED_DOMAINS=${FAUCET_GOOGLE_AUTHORIZED_DOMAINS} \
     -e ADMIN=${FAUCET_ADMIN} \
     -e REACT_DISABLE_ACCOUNT_CREATION=${FAUCET_REACT_DISABLE_ACCOUNT_CREATION} \
     -e SIFTSCIENCE_JS_SNIPPET_KEY="" \
     --cmd "yarn run start" \
     -p ${FAUCET_PORT} \
     -u ${FAUCET_USER} \
     --workingdir ${FAUCET_HOME} \
     ${STAGE0} && \
 buildah commit \
     ${STAGE0} \
     ${STAGE1} &&
 buildah tag \
     ${STAGE1} \
     ${STAGE_LATEST} &&
 buildah push \
     --dest-daemon-host ${FAUCET_DOCKER_HOST} \
     ${STAGE1} \
     docker-daemon:${STAGE1} &&
 docker \
     -H ${FAUCET_DOCKER_HOST} \
     tag \
         ${STAGE1} \
         ${STAGE_LATEST})
