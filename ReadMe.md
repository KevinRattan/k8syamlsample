# $GOOGLE_CLOUD_PROJECT must be set correctly

# Create a new Google cloud project and then run the following three steps in cloud shell

1. git clone https://github.com/KevinRattan/k8syamlsample.git
1. cd k8syamlsample
1.  . ./setup.sh

End result: a cluster running Workload Identity, with our usual trivial event app talking to firestore. Will begin with fake data because nothing there. Use the form to enter an event and from then on you should be able to talk to firestore using the permissions set up via workload identity.

UI has no firestore permissions, only the API which is running under the demoaccount service account, which is mapped to an IAM service account on which permissions have been set.