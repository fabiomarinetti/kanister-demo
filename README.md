# kanister-demo

This repo contains a demo project for a kanister-based backup. 
* The environment consists of two different data sources: an SQL database (postgreSQL) and an object store application (MinIO). 
* The backup is taken as a snapshot of the data volume using kopia.
* An AWS S3 bucket is used as snapshot repositories

## Prerequisites
To run this demo you must have:
1. a running kubernetes cluster (see appendix: How to setup a k3s single node cluster).
2. kubectl helm and kopia, installed on your client node.
3. a storage location which hosts your kopia repository. This guide uses Amazon S3 but kopia
   supports several storage backends and you could decide to use something else (https://kopia.io/docs/repositories/).

## Create the kopia repository
Before starting you should create AWS KeyPair for user with full access to the bucket created bucket. Set the following environment
variables for your AWS S3 connection:
```bash
export AWS_ACCESS_KEY_ID=<aws_access_key>
export AWS_SECRET_ACCESS_KEY=<aws_secret_access_key>
export BUCKET_NAME=<bucket_name>
export AWS_REGION=<region>
```

Choose a choose a super-secure password for your kopia repository and store its value in the environment variable:
```bash
export KOPIA_PASSWORD=<super_secure_password>
```

Finally create the kopia repository in your S3 bucket by issuing:
```bash
kopia repository create --bucket=$BUCKET_NAME \
  --region=$AWS_REGION \
  --prefix=demo/ \
  --access-key=$AWS_ACCESS_KEY_ID \
  --secret-access-key=$AWS_SECRET_ACCESS_KEY \
  --password=$KOPIA_PASSWORD
```

## Deploy and initialize datasources
Deploy minio and postgreSQL using their helm chart:
```bash
# user is pgadmin and password passw0rd
helm upgrade --install postgresql \
   -n demo \
   --create-namespace \
   oci://registry-1.docker.io/bitnamicharts/postgresql \
   -f helm/postgresql.yaml 

# user is admin and password passw0rd
helm upgrade --install minio \
    -n demo \
    --create-namespace \
    oci://registry-1.docker.io/bitnamicharts/minio \
    -f helm/minio.yaml
```

and initialize them with the correspondent initialization scripts:
```bash
kubectl cp -n demo init/postgres.sh postgresql-0:/tmp/init.sh
kubectl exec -it -n demo postgresql-0:/tmp/init.sh

minio_pod=$(kubectl get pods --selector=app.kubernetes.io/name=minio -o jsonpath="{ .items[0].metadata.name }")
kubectl cp -n demo init/minio.sh $minio_pod:/tmp/init.sh
kubectl exec -it -n demo $minio_pod -- /tmp/init.sh
```

## Upload blueprint definition and related resources
Upload ConfigMap and Secret containing the details for connecting your remote repository (i.e. bucket location, aws credentials and repository password)
```bash
envsubst < resources/location.yaml | kubectl apply -f -
envsubst < resources/credentials.yaml | kubectl apply -f -
```

Upload the blueprint definition:
```bash
kubectl apply -f blueprints/blueprint.yaml
```

## How to take backups and restore
The backup and restore actions are triggered by creating the kanister objects called ActionSet.

To backup:
```bash
kubectl create -f actions/backup.yaml
```

The backup will tag the snapshot with the application name (minio or postgresql) and the the actionset creation
timestamp (which has same value for each job in the actionset). You can find this value by showing the logs
pof any of the kopia sidecars e.g.:
<pre>
kubectl logs postgresql-0 -c kanister-tools -n demo

2023-12-05 12:33:19.049956699 -- #8 -- application name: postgresql
<b>2023-12-05 12:33:19.054057507 -- #8 -- create snapshot for backupId: 20231205123317</b>
Snapshotting root@postgresql-0:/bitnami/postgresql ...
 * 0 hashing, 1274 hashed (48.2 MB), 0 cached (0 B), uploaded 196 B, estimating...
Created snapshot with root k15e1fe06bbb9d248e75e4c6a1d410dd4 and ID 279fdacbe2ad078cc070700fcaadafe7 in 0s
2023-12-05 12:33:20.856519772 -- #8 snapshot created
</pre>

For restoring: insert this value in the restore actionset for restoring that backup level. Note there are two places
where this value needs to be changed.
<pre>
artifacts:
  context:
    keyValue:
      pvc: data-postgresql-0
<b>     backupId: "20231205123317"</b>
</pre>

then create the restore actionset by doing:
```bash
kubectl create -f actions/restore.yaml
```


## Appendix A: How to setup a k3s based environment
The project relies to standard kubernetes features so it is not designed explicitely for k3s,
but for the sake of simplicity I setup a single node environment.

Install k3s by launching:
```bash
curl -sfL https://get.k3s.io | sh -
```

## Appendix B: How to install kanister 
Start by adding the Kanister repository to your local setup:
```bash
helm repo add kanister https://charts.kanister.io/
```

Use the helm install command to install Kanister in the kanister namespace:
```bash
helm -n kanister upgrade --install kanister --create-namespace kanister/kanister-operator
```

Confirm that the Kanister workloads are ready:
```bash
kubectl -n kanister get po
```

You should see the operator pod in the Running state:
```bash
NAME                                          READY   STATUS    RESTARTS        AGE
kanister-kanister-operator-85c747bfb8-dmqnj   1/1     Running   0               15s
```


## References
* Kanister home page (https://kanister.io/)
* Kopia home page (https://kopia.io/)
* K3s documentation (https://docs.k3s.io/)
* How to create AWS bucket (https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html)
