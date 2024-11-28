# PayMyBuddy

PayMyBuddy is a java application allows users to manage financial transactions. It includes a Spring Boot backend and MySQL database. 

*I will be using a remote machine but you can do this project on your laptop 🚀*

## VM Installation 

- First, ensure you have both Vagrant and VirtualBox using [documentation](https://developer.hashicorp.com/vagrant/install) installed. I'm using ubuntu as OS, so here is the commands to install vgarant and setup a VM.

```sh
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant
```

![1](https://github.com/user-attachments/assets/a431b718-db50-4a78-8977-f9f37610d892)


- Create a Vagrantfile with a ubuntu (ask for the project)

```ruby
Vagrant.configure("2") do |config|
  config.vm.define "ubuntu" do |ubuntu|
    ubuntu.vm.box = "ubuntu/focal64"
    ubuntu.vm.box_version = "20240821.0.1"
    # Forwarded port for PayMyBuddy app
    ubuntu.vm.network "forwarded_port", guest: 8080, host: 8090
    ubuntu.vm.network "forwarded_port", guest: 3306, host: 3306

    # Forwarded port for private registry
    docker.vm.network "forwarded_port", guest: 8081, host: 8091
    docker.vm.network "forwarded_port", guest: 8088, host: 8098

    ubuntu.vm.hostname = "ubuntu"
    ubuntu.vm.provider "virtualbox" do |v|
      v.name = "ubuntu"
      v.memory = 1024
      v.cpus = 2
    end
  end
end
```
***In total, we'll need to forward 4 ports: 2 for the PayMyBuddy application and 2 for the private registry.***
-  Start the VM and connect 
 
   ```bash
   vagrant up && vagrant ssh
   ```



- Install Docker & Docker Compose

*Once everything has gone according to plan and  connected to the configured VM.* **_Since  Docker and Docker Compose is not installed_**, run the following commands to install (Tips : use the script from [get.docker](https://get.docker.com/) )
```sh

# Download the script
curl -fsSL https://get.docker.com -o install-docker.sh

# Verify the script's content
cat install-docker.sh

# Run the script with --dry-run to verify the steps it executes
sh install-docker.sh --dry-run

# Run the script either as root, or using sudo to perform the installation.
sudo sh install-docker.sh
```

For Docker compose, use this commands : 
```bash 
# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```



## Clone and Set Up the Project

- Clone the project and copy to the root

```bash
git clone https://github.com/eazytraining/bootcamp-project-update.git
cd bootcamp-project-update && cp mini-projet-docker ~
```

- Write the Dockerfile to run the app
```Dockerfile
# Dockerfile for the API
FROM amazoncorretto:17-alpine
LABEL maintainer="zakarieh"

# Copy jar file 
COPY target/paymybuddy.jar paymybuddy.jar

# Expose port 8080 
EXPOSE 8080

# Run the java script
ENTRYPOINT ["java","-jar","paymybuddy.jar"]  
```

- Docker-compsoe 
```yml
version: "3.8"

services:
  paymybuddy-backend:
  #  build:
  #    context: .
  #    dockerfile: Dockerfile
    image: devops.mediker.fr:8098/paymybuddy-backend
    container_name: backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    depends_on:
      paymybuddy-db:
        condition: service_healthy
    environment:
      - SPRING_DATASOURCE_URL=jdbc:mysql://paymybuddy-db:3306/db_paymybuddy
      - SPRING_DATASOURCE_USERNAME=${SPRING_DATASOURCE_USERNAME}
      - SPRING_DATASOURCE_PASSWORD=${SPRING_DATASOURCE_PASSWORD}
    secrets:
      - env
    networks:
      - paymybuddy_network

  paymybuddy-db:
    image: devops.mediker.fr:8098/paymybuddy-db
    container_name: database
    restart: always
    environment:
    #  MYSQL_DATABASE: 'db'
    #  MYSQL_USER: 'user'
    #  MYSQL_PASSWORD: 'password'
      MYSQL_ROOT_PASSWORD: /run/secrets/env
    secrets:
      - env
    ports:
      - '3306:3306'
    healthcheck:
      test: ["CMD", "mysqladmin" ,"ping", "-h", "localhost"]
      retries: 10
      interval: 3s
      timeout: 30s
    volumes:
      - ./initdb/create.sql:/docker-entrypoint-initdb.d/create.sql:ro
      - my-db:/var/lib/mysql
    networks:
      - paymybuddy_network

networks:
  paymybuddy_network:
    driver: bridge

volumes:
  my-db:

secrets:
  env:
    file: ./.env
```

 ![Screenshot 2024-11-26 183126](https://github.com/user-attachments/assets/750ad0ae-5356-4df8-a6aa-ef42deaa27f8)
![Screenshot 2024-11-26 193059](https://github.com/user-attachments/assets/54f76b1c-22ad-4bee-92e9-80384c15a01e)



 

## Private Registry 
- As I'm using a remote machine with http, I'll edit the `/etc/docker/daemon.json` file. Don't use this on prod or in the real registries, you can use certificates.

```bash
sudo nano /etc/docker/daemon.json
```
- The wil look like : 
```json
{
  "insecure-registries": ["ip:8088", "devops.mediker.fr:8098"]
}
```

> Where ip is representing the pulic ip of remote mcahine and url of your machine

- After editing the file, you need to restart to apply the changes.

```bash
sudo systemctl restart docker.service
```

- docker-compose for private registry
```yml
version: "3.8"

services:
  # Docker Registry Server - The registry service that stores the Docker images
  registry-server:
    image: registry:2.8.2
    restart: always
    ports:
      - "8081:5000"
    environment:
      REGISTRY_HTTP_HEADERS_Access-Control-Allow-Origin: "[http://registry.example.com]"
      REGISTRY_HTTP_HEADERS_Access-Control-Allow-Methods: "[HEAD,GET,OPTIONS,DELETE]"
      REGISTRY_HTTP_HEADERS_Access-Control-Allow-Credentials: "[true]"
      REGISTRY_HTTP_HEADERS_Access-Control-Allow-Headers: "[Authorization,Accept,Cache-Control]"
      REGISTRY_HTTP_HEADERS_Access-Control-Expose-Headers: "[Docker-Content-Digest]"
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    volumes:
      - ./registry/data:/var/lib/registry # Data directory
      - ./config.yml:/etc/docker/registry/config.yml # Mount the config file
      - ./htpasswd:/etc/docker/registry/htpasswd # Mount the config file
    container_name: registry-server

    # Docker Registry UI - Frontend web interface for registry
  registry-ui:
    image: joxit/docker-registry-ui:main
    restart: always
    ports:
      - "8088:80" # Exposing port 8088 for the UI to be accessible on the host
    environment:
      - SINGLE_REGISTRY=true # If true, it assumes only one registry is configured
      - REGISTRY_TITLE=Docker Registry UI # The title for the UI
      - DELETE_IMAGES=true # Allows image deletion via UI
      - SHOW_CONTENT_DIGEST=true # Shows digest of content in the UI
      - NGINX_PROXY_PASS_URL=http://registry-server:8081 # The URL of the registry server
      - SHOW_CATALOG_NB_TAGS=true # Show number of tags in the catalog
      - CATALOG_MIN_BRANCHES=1 # Minimum branches for catalog display
      - CATALOG_MAX_BRANCHES=1 # Maximum branches for catalog display
      - TAGLIST_PAGE_SIZE=100 # Number of tags per page in the tag list
      - REGISTRY_SECURED=false # If true, enforces secure HTTPS access
      - CATALOG_ELEMENTS_LIMIT=1000 # Limit for catalog elements
    container_name: registry-ui # Name for the container
```
- config.yml

```sh
version: 0.1
log:
  fields:
    service: registry
storage:
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :8081
  headers:
    X-Content-Type-Options: [nosniff]
    Access-Control-Allow-Origin: ['http://127.0.0.1:8088']
    Access-Control-Allow-Methods: ['HEAD', 'GET', 'OPTIONS', 'DELETE']
    Access-Control-Allow-Headers: ['Authorization', 'Accept', 'Cache-Control']
    Access-Control-Max-Age: [1728000]
    Access-Control-Allow-Credentials: [true]
    Access-Control-Expose-Headers: ['Docker-Content-Digest']
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/docker/registry/htpasswd
```
- htpasswd file 
```sh
docker:$2a$12$lQA3qE4wbr1B/aIoO4orOeCuR9f/EzBhxNrN94rY41vFxDdsFHWMK
```
You can create and verify the bcrypt password from : https://bcrypt-generator.com/

- Login to the registry
```sh 
docker login devops.mediker.fr:8098 -u docker -p docker
``` 
![3](https://github.com/user-attachments/assets/0b8c50b7-2918-4d73-afa0-abbd839deea5)

> Where is user=docker and pasword=docker

- Change tag with `docker tag` and push

```sh
docker tag 3818a28b4a67  devops.mediker.fr:8098/paymybuddy-db
docker tag f1ec72625aa4 devops.mediker.fr:8098/paymybuddy-backend
docker push devops.mediker.fr:8098/paymybuddy-db
docker push devops.mediker.fr:8098/paymybuddy-backend
```
![2](https://github.com/user-attachments/assets/37a7a2cb-befb-4dc8-8eee-dd1019f6fab6)


![4](https://github.com/user-attachments/assets/a25d397b-a116-470d-a522-8ad22253cd2a)
