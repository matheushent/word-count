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
