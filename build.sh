#!/bin/sh -x

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

./gradlew build --refresh-dependencies
./gradlew app:dependencies

# Default is Develop using above environment variables
# Staging
echo "===== Build NewPipe .apk for AppCenter ====="
if [ "$GIT_BRANCH" = "staging" ]; then 
  APP_ENV="Staging"
  APP_KEY="NewPipe_staging"
  ./gradlew assembleStaging
  APK_LOCATION=app/build/outputs/apk/staging/debug/app-staging-debug.apk
# Production
elif [ "$GIT_BRANCH" = "main" ]; then
  SDK_ENV='Prod'
  ./gradlew assembleProd
  APK_LOCATION=app/build/outputs/apk/prod/debug/app-prod-debug.apk
elif [ "$GIT_BRANCH" = "develop" ]; then
  SDK_ENV='Dev'
  ./gradlew assembleDev
  APK_LOCATION=app/build/outputs/apk/dev/NewPipe_HEAD-dev.apk
fi

# We use lowercase variables as part of the Artifactory BDD path below
LOWERCASE_APP_ENV=$( tr '[A-Z]' '[a-z]' <<< $APP_ENV)
LOWERCASE_SDK_ENV=$( tr '[A-Z]' '[a-z]' <<< $SDK_ENV)


echo "===== Uploading .apk to AppCenter ====="
appcenter distribute release --app Contextual/NewPipe-"$SDK_ENV"SDK-"$APP_ENV"-"$APP_KEY" --file "$APK_LOCATION" --group "Collaborators"
