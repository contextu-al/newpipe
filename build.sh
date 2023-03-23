#!/bin/sh

# If user has set CONTEXTUAL_SDK_VERSION in environment, it will be used.
# If user did not set the variable, the default will be used, 2.+
if [ "$CONTEXTUAL_SDK_VERSION" ]; then
    echo "VERSION_NAME=${CONTEXTUAL_SDK_VERSION}:2.+" >> local.properties
    echo "Building ${CONTEXTUAL_SDK_VERSION} of SDK"
fi


# Invoked from upstream SDK pipeline.
if [ ! -f local.properties ]; then
   git clone https://gitlab.com/contextual/sdks/android/contextual-sdk-android
   cd contextual-sdk-android
   git checkout $UPSTREAM_VERSION_NAME
   CONTEXTUAL_SDK_TAG=$(git describe --tags --abbrev=0)
   UPSTREAM_VERSION_GIT_HASH=-${UPSTREAM_VERSION_NAME}
   UPSTREAM_VERSION=${CONTEXTUAL_SDK_TAG}${UPSTREAM_VERSION_GIT_HASH}
   cd ..
   echo "VERSION_NAME=${UPSTREAM_VERSION}" >> local.properties
   echo "Building ${UPSTREAM_VERSION} of SDK"
fi

echo "===== Ensuring correct language encoding and paths on build machine ====="
source ~/.profile

echo "===== Cleanup before fresh build ====="
rm -rf .app/build/outputs

echo "===== Determine git branch name ====="
if [ -z "$CI_COMMIT_REF_NAME" ]; then
    GIT_BRANCH=$(git symbolic-ref --short -q HEAD)
else
    GIT_BRANCH=$CI_COMMIT_REF_NAME
fi

echo "===== Setting Default Environment Variables ======"
APP_ENV="Prod"
APP_KEY="NewPipe"
SDK_ENV="Dev"

GIT_VERSION=$(git log -1 --format="%h")
BUILD_TIME=$(date)
APK_LOCATION=""

# Default is Develop using above environment variables
# Staging
echo "===== Build NewPipe .apk for AppCenter ====="
  if [ "$GIT_BRANCH" = "staging" ]; then
  APP_ENV="Staging"
  APP_KEY="NewPipe_staging"
  ./gradlew assembleStagingDebug
  APK_LOCATION=app/build/outputs/apk/staging/debug/app-staging-debug.apk
# Production
elif [ "$GIT_BRANCH" = "main" ]; then
  SDK_ENV='Prod'
  ./gradlew assembleProdDebug
  APK_LOCATION=app/build/outputs/apk/prod/debug/app-prod-debug.apk
elif [ "$GIT_BRANCH" = "develop" ]; then
  SDK_ENV='Dev'
  ./gradlew assembleContinuousIntegrationDebug
  APK_LOCATION=app/build/outputs/apk/continuousIntegration/debug/app-continuousIntegration-debug.apk
fi

# We use lowercase variables as part of the Artifactory BDD path below
LOWERCASE_APP_ENV=$( tr '[A-Z]' '[a-z]' <<< $APP_ENV)
LOWERCASE_SDK_ENV=$( tr '[A-Z]' '[a-z]' <<< $SDK_ENV)


echo "===== Uploading .apk to AppCenter ====="
appcenter distribute release --app Contextual/NewPipe-"$SDK_ENV"SDK-"$APP_ENV"-"$APP_KEY" --file "$APK_LOCATION" --group "Collaborators"
