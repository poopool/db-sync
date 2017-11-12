#!/bin/bash

BB_BRANCH=${BB_BRANCH:-master}
RUN_TEST=${RUN_TEST}

type=${type}
project_id=${project_id}
private_key_id=${private_key_id}
private_key=${private_key}
client_email=${client_email}
client_id=${client_id}
auth_uri=${auth_uri}
token_uri=${token_uri}
auth_provider_x509_cert_url=${auth_provider_x509_cert_url}
client_x509_cert_url=${client_x509_cert_url}


echo Installing required packages, this might take few moments...
apt-get -qq update
apt-get -qq install openssl lsb-release wget curl -y

echo Installing google cloud sdk, , this might take few moments...
export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"
echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

apt-get -qq update
apt-get -qq install google-cloud-sdk -y

echo Installing rethinkdb python driver
pip install rethinkdb

#assemble auth token
cat << EOF > /root/token.json
{
  "type": "$type",
  "project_id": "$project_id",
  "private_key_id": "$private_key_id",
  "private_key": "$private_key",
  "client_email": "$client_email",
  "client_id": "$client_id",
  "auth_uri": "$auth_uri",
  "token_uri": "$token_uri",
  "auth_provider_x509_cert_url": "$auth_provider_x509_cert_url",
  "client_x509_cert_url": "$client_x509_cert_url"
}
EOF

#Configuring gsutils
cat << EOF > /root/.boto
[Credentials]
gs_service_key_file = /root/token.json
[Boto]
https_validate_certificates = True
[GoogleCompute]
[GSUtil]
content_language = en
default_api_version = 2
[OAuth2]
EOF

mkdir -p /app/apl_common

pip install https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-common/get/$BB_BRANCH.zip
pip install https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-db-utils/get/$BB_BRANCH.zip

git clone -b $BB_BRANCH https://applariat:$BB_API_KEY@bitbucket.org/applariat/apl-common.git /app/apl_common

export PYTHONPATH=/app

cd /app/apl_common

echo 'Seeding DB now...'
python - <<-EOF
PROJECT_ROOT='/app'
import db_sync
db_sync.main()
EOF
echo 'Done Seeding DB...'

sleep 10

if [ $RUN_TEST = true ]
then
  echo "RUN_TEST flag is set, going to run tester.sh script..."
  git clone https://applariat:$BB_API_KEY@bitbucket.org/applariat/automated-testing
  cd automated-testing/
  bash -x tester.sh
fi