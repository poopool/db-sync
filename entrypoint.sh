#!/bin/bash

BB_API_KEY=${BB_API_KEY}
BB_BRANCH=${BB_BRANCH:-master}
RUN_TEST=${RUN_TEST}
BACKUP_DOWNLOAD_URL=${BACKUP_DOWNLOAD_URL}
RESTORE_DB=${RESTORE_DB}

echo Installing required packages, this might take few moments...
apt-get -qq update
apt-get -qq install openssl wget curl -y


if [ $RESTORE_DB = true ]
then
  echo Installing rethinkdb python driver
  pip install rethinkdb
  #Downloading and restore backupfile
  wget $BACKUP_DOWNLOAD_URL -O backup.tar.gz
  rethinkdb-restore backup.tar.gz -c rethinkdb:28015 --force
fi

mkdir -p /app/apl-db-utils

pip install https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-common/get/$BB_BRANCH.zip
pip install https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-db-utils/get/$BB_BRANCH.zip

git clone -b $BB_BRANCH https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-db-utils.git /app/apl-db-utils
export PYTHONPATH=/app

cd /app/apl-db-utils/db_utils

echo 'Syncing RethinkDB now...'
python - <<-EOF
PROJECT_ROOT='/app/apl-db-utils/db_utils'
import db_sync
db_sync.main()
EOF
echo 'Done Syncing RethinkDB...'

sleep 10

if [ $RUN_TEST = true ]
then
  echo "RUN_TEST flag is set, going to run tester.sh script..."
  git clone https://applariat:$BB_API_KEY@bitbucket.org/applariat/automated-testing
  cd automated-testing/
  bash -x tester.sh
fi