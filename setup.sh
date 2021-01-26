# enable cloud build and firestore apis
echo 'enabling services'
gcloud services enable cloudbuild.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable appengine.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable iamcredentials.googleapis.com
# create directory, download code from github
echo 'downloading from github'
git clone https://github.com/KevinRattan/sample.git --branch firestorewithtests
# create and build the images
echo 'building images for this project'
cd sample/internal
cat > Dockerfile <<EOF
FROM launcher.gcr.io/google/nodejs
COPY . /app/
WORKDIR /app
RUN npm install
CMD ["node", "server.js"]
EOF
gcloud builds submit -t gcr.io/$GOOGLE_CLOUD_PROJECT/internal:v0.2 .
cd ../external
cat > Dockerfile <<EOF
FROM launcher.gcr.io/google/nodejs
COPY . /app/
WORKDIR /app
RUN npm install
CMD ["node", "server.js"]
EOF
gcloud builds submit -t gcr.io/$GOOGLE_CLOUD_PROJECT/external:v0.2 .
# Create appengine app to get firestore
echo 'creating app engine to enable firestore'
gcloud app create --region=us-central
# Create a firestore native database
echo 'creating firestore native db'
gcloud beta firestore databases create --region=us-central
# Create a cluster with workload identity enabled and no scopes enabled
echo 'creating cluster with workload identity enabled'
gcloud container clusters create cluster-demo --zone us-central1-a --num-nodes 3 --preemptible --no-enable-autoupgrade --workload-pool=$GOOGLE_CLOUD_PROJECT.svc.id.goog
# Get credentials on the cluster
echo 'getting credentials'
gcloud container clusters get-credentials cluster-demo --zone us-central1-a --project $GOOGLE_CLOUD_PROJECT
# Create namespace to permission
echo 'creating namespace demo'
kubectl create namespace demo
# Create service account for the namespace
echo 'creating serviceacoount demoaccount in namespace demo'
kubectl create serviceaccount --namespace demo demoaccount
# Create IAM service account
echo 'creating cloud iam service account demogsa'
gcloud iam service-accounts create demogsa
# bind the two together
echo 'binding k8s and gsa service accounts together'
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GOOGLE_CLOUD_PROJECT}.svc.id.goog[demo/demoaccount]" \
  demogsa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
# add annotation for GCP IAM to kubernetes
echo 'add anotation for IAM to k8s'
kubectl annotate serviceaccount --namespace demo demoaccount \
  iam.gke.io/gcp-service-account=demogsa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com
# Assign firestore permissions to the Google service account
echo 'assign firestore permissions to demogsa'
gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT \
    --member=serviceAccount:demogsa@$GOOGLE_CLOUD_PROJECT.iam.gserviceaccount.com --role=roles/datastore.user
# modify yaml for this project
echo 'customizing yaml for this project'
cd ../../demo
echo 'customizing yaml for this project'
sed -i 's/PROJID/'"$GOOGLE_CLOUD_PROJECT"'/g' api-deployment.yaml
sed -i 's/PROJID/'"$GOOGLE_CLOUD_PROJECT"'/g' ui-deployment.yaml
# deploy demo app that uses firestore
echo 'deploying app'
kubectl apply -k .
# set the service account for the api deployment
echo 'assign service account to api deployment'
kubectl set serviceaccount deployment demo-api demoaccount -n demo
echo 'All done. Wait a minute or two for everything to be created/recreated and you should be able to add new events and have them appear in firestore'

