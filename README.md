# Word Count

## Description
This project deploys a working infrastructure as code at AWS to deploy a service that accepts as input a text file, and produces as output a count of the
words present in the file.

The code base is Python with FastAPI for the service and Terraform with AWS EKS for the infrastructure.


In the `service` folder is the complete service implementation with Python and its Dockerfile for testing. In the `infra` folder is the infrastructure as code using Terraform.

## Word Count Service Instructions
The service is build using FastAPI and there is only one endpoint `/wc/` and it only accepts POST requests with a text file.

### Test the project locally

Create a `virtualenv`, install the dependencies from `requirements.txt` then run `pytest`:

```bash
$ cd service
$ python -m virtualenv venv
$ source venv/bin/activate
(venv) $ pip install -r requirements.txt
(venv) $ pytest
(venv) $ gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker
```

#### Note
The above command to run using gunicorn exposes the default port, check the service in `localhost:8000/docs`.


### Use Docker to run the tests

#### Build the image:

```bash
$ sudo docker build -t word-count:v1 .
```

#### Then run the container and execute the `pytest` command:

```bash
$ sudo docker run --name word_count --publish 80:80 word-count:v1
$ sudo docker exec -it word_count pytest
```

#### Note
The above command run using an optimized config for gunicorn and exposes the port 80.

There is also an image in the dockerhub: `zsinx6/word-count` if needed.

#### Docker Image Information

The Docker image is based in the [tiangolo/uvicorn-gunicorn-fastapi](https://hub.docker.com/r/tiangolo/uvicorn-gunicorn-fastapi) image, which is an optimized FastAPI server in a Docker container, and auto-tuned for the server based in the and number of CPU cores.

### API Information
There is an automatic interactive API documentation (provided by Swagger UI) in the `/docs`.
In this documentation is possible to attach a file and make a POST request against the API to manually test the service, and shows all the information about the API.

There is also the alternative automatic documentation (provided by ReDoc) in the `/redoc`.

#### Using the API
First create a file with some text, then make a POST request in `/wc/`:

```bash
$ echo "two words" > testfile.txt
$ curl -X POST "http://localhost/wc/" -H  "accept: application/json" -H  "Content-Type: multipart/form-data" -F "file=@testfile.txt;type=text/plain"
```

The response for the above request is:

```
{"word_count":2}
```

#### Note
For the above test to work, the Docker container must be running, check [here](#use-docker-to-run-the-tests).
If don't want to use Docker, then add the port 8000 in the `curl` command (e.g. `http://localhost:8000/wc/`).

## Infrastructure as Code Instructions

The deploy of the infra is in two phases, first we deploy the Kubernetes cluster in the AWS EKS, along with all the needed AWS services (vpc, security groups), then we deploy the service inside the EKS cluster (using the Docker image build from the word-count service folder's Dockerfile).

In the `deploy-cluster` folder is the workspace for the EKS cluster:
- `vpc.tf` provisions a VPC, subnets and availability zones using the AWS VPC Module.
- `security-groups.tf` provisions the security groups used by the EKS cluster.
- `eks-cluster.tf` provisions all the resources (AutoScaling Groups, etc...) required to set up an EKS cluster using the AWS EKS Module.
- `outputs.tf` defines the output configuration.
- `versions.tf` sets the Terraform version to at least 0.14. It also sets versions for the providers used in this project.
- `kubernetes.tf` the Kubernetes provider is included in this file so the EKS module can complete successfully. Otherwise, it throws an error when creating `kubernetes_config_map.aws_auth`.

In the `deploy-wc-kubernetes` folder is the workspace for the service to run inside the EKS cluster:
- `kubernetes.tf` the Kubernetes provider, which deploys the `wc` service using the Docker image (`zsinx6/word-count`) created for the word-count service hosted [here](https://hub.docker.com/repository/docker/zsinx6/word-count), there is also a LoadBalancer, which routes the traffic from the external load balancer to pods matching the selector (in this case, the `service`). The output is defined to return the external ip address of the service.

### Deploy Instructions
**Warning: there could be charges when running this, since the deploy is at AWS**

Since the project uses AWS, it is expected to have the aws-cli already installed and configured (see [here](https://docs.aws.amazon.com/cli/index.html) for detailed information).

#### First initialize the Terraform workspace for the EKS:

```bash
$ cd infra/deploy-cluster
$ terraform init
```

#### Then apply the configuration to the AWS, type `yes` when asked:
```bash
$ terraform apply
```

The above step should take approximately 20 minutes, and when finished the EKS cluster will be available and the Terraform will print the outputs defined in the `outputs.tf`.

#### The next step is to configure the `kubectl`:
```bash
$ aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)
```

Now the `kubectl` tool should work.

#### Now initialize the Terraform workspace for the service that will deploy inside the EKS cluster:

```bash
$ cd infra/deploy-wc-kubernetes
$ terraform init
```

#### Then apply the configuration to the AWS, type `yes` when asked:
```bash
$ terraform apply
```

Now the deploy is complete, and the word-count service should already be available, the above command outputs the ip address for the service.

To check the running services (this commands also display the external-IP):

```bash
$ kubectl get services
```

### How to upgrade the running image
There are 2 ways to upgrade the running image:

For both we need to change the service source code, rebuild the Docker image using an updated tag for the version and push the image to a registry (e.g. dockerhub).
The first one is the recommended, since we can use the `kubectl` directly.

Then we can run the following command to update the deployment inside the EKS cluster:

```bash
$ kubectl set image deployments/scalable-word-count word-count=zsinx6/word-count:v2
```

Or change the `infra/deploy-wc-kubernetes/kubernetes.tf` to use the updated image, then apply the terraform:
```
resource "kubernetes_deployment" "wc" {
  # ...

  spec {
    # ...

    template {
      # ...

      spec {
        container {
          image = "zsinx6/word-count:v2"
          # ...
      }
    }
  }

  # ...
}
```

```bash
$ terraform apply
```

### How to scale
There are also 2 ways to scale, the first one is the recommended.

Just use the `kubectl`:

```bash
$ kubectl scale deployment/scalable-word-count --replicas=4
```


Or change the number of `replicas` inside the `infra/deploy-wc-kubernetes/kubernetes.tf` in the deployment resource and use terraform to apply:

```
resource "kubernetes_deployment" "wc" {
  # ...

  spec {
    replicas = 4

    # ...
  }

  # ...
}

```

Then update the AWS:

```bash
$ terraform apply
```


### How to monitor

Since the EKS is at AWS, it has the AWS CloudWatch, and we can easily check the EC2 and the EKS cluster health state along with the metrics.


### How to clean the AWS

Terraform has the `destroy` command:

```bash
$ cd infra/deploy-wc-kubernetes
$ terraform destroy
$ cd infra/deploy-cluster
$ terraform destroy
```
