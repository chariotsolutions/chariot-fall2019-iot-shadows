# Chariot Fall 2019 IoT on AWS Event
Code needed to demonstrate AWS device shadows and mobile app client to interact with a device

Requirements:
* AWS CLI
* AWS Amplify Framework CLI: https://aws-amplify.github.io/docs/
* For iOS development - Cocoapods: https://cocoapods.org/
* AWS iOS SDK: https://aws-amplify.github.io/docs/ios/start
  * current project uses drop in authentication: https://aws-amplify.github.io/docs/ios/authentication#drop-in-auth
  * IoT MQTT set up: https://aws-amplify.github.io/docs/ios/pubsub
    * when attempting to attach the IoT policy to the Cognito Identity, the identity can also be found using the amazon console and browsing identities (after creating your user account via the app)
    * see the sample-iot-policy.txt document for the IoT policy definition to use
    * also need to add the AWSIoTDataAccess policy to the IAM Authorized role
