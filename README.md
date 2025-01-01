# Functionbeat

Functionbeat is defined as a “serverless” shipper that can be deployed as a function to collect and ship data into the ELK Stack. Designed for monitoring cloud environments, Functionbeat is currently tailored for Amazon setups and can be deployed as an Amazon Lambda function to collect data from Amazon CloudWatch, Kinesis and SQS.

We will create and deploy fuctionbeat to read cloudwatch logs generated from a aws lambda function and ship them to an elasticsearch instance.


## setup Elasticsearch

## Creat key pair
https://console.aws.amazon.com/ec2/ >
NETWORK & SECURITY >
Key Pairs.
Create Key Pair

The private key file is automatically downloaded by your browser

set permissions so only you can read it:
`$ chmod 400 my-key-pair.pem`

## Create Ec2 instsance

I used t2.small  linux (but t2.large would be better)

### Add vpc: default:
![out](img/out1.png)
![out](img/out2.png)


### configure security group to open SSH(22), Elasticsearch(9200, 9300) and Kibana(5601) ports

![out](img/out3.png)

Inbound open ports:
Ports	Protocol	Source	EC2-SSH
22	    tcp	        0.0.0.0/0	✔
5601	tcp	        0.0.0.0/0	✔
9300	tcp	        0.0.0.0/0	✔
5400	tcp	        0.0.0.0/0	✔
9200	tcp	        0.0.0.0/0	✔

Outbound rules: all

Ports	Protocol	Destination	EC2-SSH
All	    All	        0.0.0.0/0	    ✔

### Add elastic IP

EC2> Elastic IP > select instance> associate elastic ip to instance

![out](img/out4.png)

### specify the previously created keypair.


## Login to ec2 instance

ec2 console> instance name> click connect > run ssh command given in terminal

cd into location you downloaded the keypair and execute ssh to connect:

```sh
(base)  ✘ rdissanayakam@RBH12855  ~/vp/aws_access_keys  pwd                                                                            
/Users/rdissanayakam/vp/aws_access_keys
(base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  ls
logstash_keypair.pem  
(base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  ssh -i "logstash_keypair.pem" ec2-user@ec2-3-213-192-20.compute-1.amazonaws.com
Last login: Wed Jul 10 15:00:21 2019 from 204.26.112.13

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
No packages needed for security; 6 packages available
Run "sudo yum update" to apply all updates.
```

now login as root:

```sh
[ec2-user@ip-172-31-62-80 ~]$ sudo su -
Last login: Wed Jul 10 15:00:23 UTC 2019 on pts/0
[root@ip-172-31-62-80 ~]# 
```

## install java
`$ sudo yum install java-1.8.0-openjdk-devel`

check version;
`$ java -version`

output:
```sh
openjdk version "1.8.0_201"
OpenJDK Runtime Environment (build 1.8.0_201-b09)
OpenJDK 64-Bit Server VM (build 25.201-b09, mixed mode)
```

##  add the Elasticsearch repository

Import the repository’s GPG key using the following command:
`$ sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch`

Open your text editor and create the following repo file:
`$ sudo vi /etc/yum.repos.d/elasticsearch.repo`

copy and save following, then close test editor:
```sh
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
```

or:

cat > /etc/yum.repos.d/elasticsearch.repo << "EOF"
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF



## install the Elasticsearch package
`$ sudo yum install elasticsearch`

## modify elasticsearch.yml:

Now we need to change networkhost so it is not locahost anymore:

[root@ip-172-31-62-80 ~]# `netstat -nptl`
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name          
tcp6       0      0 `127.0.0.1:9200  `     :::*                    LISTEN      5460/java           
tcp6       0      0 `127.0.0.1:9300 `      :::*                    LISTEN      5460/java           

Notice it is set to loopback address. lets change it throufh elasticsearch.yml

```sh
vi /etc/elasticsearch/elasticsearch.yml
```

change network host to private ip of the ec2 instance so it can be accessed from outside(lambda):

```json
network.host: 172.31.62.80
```



## Run elasticsearch as a service

```sh
$ sudo systemctl enable elasticsearch.service
$ sudo systemctl start elasticsearch.service
```

Start service and set it to auto run on boot up

```sh
/etc/init.d/elasticsearch status
sudo chkconfig --levels 235 elasticsearch on


$ sudo service elasticsearch stop
$ sudo service elasticsearch start
$ sudo service elasticsearch status
```

Now ip is corrected so that elasticsearch service is accessible from outside through ip:
[root@ip-172-31-62-80 ~]# `netstat -nptl`
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name           
tcp6       0      0 `172.31.62.80:9200 `      :::*                    LISTEN      5460/java           
tcp6       0      0 `172.31.62.80:9300 `      :::*                    LISTEN      5460/java                 
[root@ip-172-31-62-80 ~]# 

## check if runnig
`$ sudo systemctl status elasticsearch.service`

or better yet (both public ip and private ip in ec2 instace in url works)
`sudo curl -XGET 'http://3.213.192.20:9200/_cat/indices?v&pretty'`

```sh
[root@ip-172-31-62-80 ~]# sudo curl -XGET 'http://3.213.192.20:9200/_cat/indices?v&pretty'
health status index                         uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .kibana_1                     kY8iQBMsT1iGBJXj1FiIcg   1   0          5            1     40.4kb         40.4kb
green  open   .kibana_task_manager          yKn_5v5wSvm489h7HshNgQ   1   0          2            0     12.6kb         12.6kb
yellow open   accounts                      oDNcG3EYScitVEKMCKq6ZQ   5   1          2            0     10.5kb         10.5kb
yellow open   functionbeat-7.2.0-2019.07.10 9yxPz0MkR96IrR-kkgjcEQ   1   1         13            0     37.9kb         37.9kb
```
```sh
sudo curl -XGET 'http://172.31.62.80:9200/_cat/indices?v&pretty'
health status index                         uuid                   pri rep docs.count docs.deleted store.size pri.store.size
green  open   .kibana_1                     kY8iQBMsT1iGBJXj1FiIcg   1   0          5            1     40.4kb         40.4kb
green  open   .kibana_task_manager          yKn_5v5wSvm489h7HshNgQ   1   0          2            0     12.6kb         12.6kb
yellow open   accounts                      oDNcG3EYScitVEKMCKq6ZQ   5   1          2            0     10.5kb         10.5kb
yellow open   functionbeat-7.2.0-2019.07.10 9yxPz0MkR96IrR-kkgjcEQ   1   1         13            0     37.9kb         37.9kb
```

```json
{
  "name" : "fLVNqN_",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "6zKcQppYREaRH0tyfJ9j7Q",
  "version" : {
    "number" : "6.7.0",
    "build_flavor" : "default",
    "build_type" : "rpm",
    "build_hash" : "8453f77",
    "build_date" : "2019-03-21T15:32:29.844721Z",
    "build_snapshot" : false,
    "lucene_version" : "7.7.0",
    "minimum_wire_compatibility_version" : "5.6.0",
    "minimum_index_compatibility_version" : "5.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

To view the messages logged by the Elasticsearch service you can use the command below:

`$  sudo journalctl -u elasticsearch`


## Create test index
`curl -X PUT "http://127.0.0.1:9200/mytest_index"
{"acknowledged":true,"shards_acknowledged":true,"index":"mytest_index"}`


## check indices
`sudo curl -XGET 'http://172.31.62.80:9200/_cat/indices?v&pretty'`


## post:
 curl -X POST 172.31.62.80:9200/accounts/person/2 -curl -H 'Content-Type: application/json' -d '
 {
     "name" : "John",
     "lastname" : "Doe",
     "job_description" : "Systems administrator and Linux specialit"
 }
 '

## get:
curl -X GET 172.31.62.80:9200/accounts/person/1


# Install kibana in ec2 instance -linux

## Download and install the Public Signing  Key (Already done from above)
`sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch`

Next create a file called “kibana.repo” in “/etc/yum.repos.d/” directory
`sudo vi /etc/yum.repos.d/kibana.repo`

Then add the following config into the repository created above
[kibana-5.x]
name=Kibana repository for 5.x packages
baseurl=https://artifacts.elastic.co/packages/5.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

open port 5601 in security group of ec2 instance

##  install kibana
`sudo yum install kibana`

## change kibana.yml configuration

Notice kibana points to loopback/localhost:

```sh
[root@ip-172-31-62-80 ~]# `netstat -nptl`
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name          
tcp        0      0 `127.0.0.1:5601`       0.0.0.0:*               LISTEN      3468/node           
```


```sh
vi /etc/kibana/kibana.yml
```
change server host to private ip of ec2 instance:

```json
server.host: "172.31.62.80"
```

change elasticsearch.hosts to use ec2 private ip:

```json
elasticsearch.hosts: ["http://172.31.62.80:9200"]
```

## Start Kibana
`sudo -i service kibana stop`
`sudo -i service kibana start`

```sh
[root@ip-172-31-62-80 ~]# `netstat -nptl`
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name          
tcp     0      0    172.31.62.80:5601     0.0.0.0:*               LISTEN      3468/node    
```
Check if you are running Systemd or SysV init
`ps -p 1`

—– For SysV init —–
`sudo chkconfig --add kibana`
`sudo -i service kibana stop`
`sudo -i service kibana start`

—– For systemd —–
`sudo /bin/systemctl daemon-reload`
`sudo /bin/systemctl enable kibana.service`
`sudo systemctl stop kibana.service`
`sudo systemctl start kibana.service`

## access your kibana page with following URL:
http://3.213.192.20:5601/app/kibana


# FunctionBeat

https://logz.io/blog/beats-tutorial/

## What are Beats?
Beats are a collection of lightweight (resource efficient, no dependencies, small) and open source log shippers that act as agents installed on the different servers in your infrastructure for collecting logs or metrics.

These can be 
- log files (Filebeat), 
- network data (Packetbeat), 
- server metrics (Metricbeat), 

or any other type of data that can be collected by the growing number of Beats being developed by both Elastic and the community. Once collected, the data is sent either directly into Elasticsearch or to Logstash for additional processing.

Beats are built on top of a Go framework called libbeat — a library for data forwarding which means that new beats are being developed and contributed by the community all the time.

### Functionbeat
Functionbeat is defined as a “serverless” shipper that can be deployed as a function to collect and ship data into the ELK Stack. Designed for monitoring cloud environments, Functionbeat is currently tailored for Amazon setups and can be `deployed as an Amazon Lambda function` to collect data from Amazon CloudWatch, Kinesis and SQS.

## Install functionbeat

1. bring up linux ec2 instance

2. ssh into it

    ssh -i "logstash_keypair.pem" ec2-user@ec2-18-234-167-255.compute-1.amazonaws.com

    ```bash
    (base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  pwd
    /Users/rdissanayakam/vp/aws_access_keys
    (base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  ls
    logstash_keypair.pem        logstash_keypair_public.pem tmp.json
    (base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  ssh -i "logstash_keypair.pem" ec2-user@ec2-18-234-167-255.compute-1.amazonaws.com
    The authenticity of host 'ec2-18-234-167-255.compute-1.amazonaws.com (127.0.0.1)' can't be established.
    ECDSA key fingerprint is SHA256:BT44tRbfvTKE3q5z1NsM/imn2rk9JvcuzWZXepZoLyI.
    Are you sure you want to continue connecting (yes/no)? yes
    Warning: Permanently added 'ec2-18-234-167-255.compute-1.amazonaws.com' (ECDSA) to the list of known hosts.

        __|  __|_  )
        _|  (     /   Amazon Linux 2 AMI
        ___|\___|___|

    https://aws.amazon.com/amazon-linux-2/
    No packages needed for security; 6 packages available
    Run "sudo yum update" to apply all updates.
    [ec2-user@ip-172-31-63-184 ~]$ 
    ```

3. login as root

    $ sudo su -

    ```bash
    [ec2-user@ip-172-31-63-184 ~]$ sudo su -
    [root@ip-172-31-63-184 ~]
    ```
4. install functionbeat

    curl -L -O https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-7.2.0-linux-x86_64.tar.gz
tar xzvf functionbeat-7.2.0-linux-x86_64.tar.gz

    ```bash
    [root@ip-172-31-63-184 ~]# curl -L -O https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-7.2.0-linux-x86_64.tar.gz
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
    100 47.2M  100 47.2M    0     0  48.7M      0 --:--:-- --:--:-- --:--:-- 48.6M
    [root@ip-172-31-63-184 ~]#

    [root@ip-172-31-63-184 ~]# ls
f   unctionbeat-7.2.0-linux-x86_64.tar.gz
    ```


5. extract functionbeat-7.2.0-linux-x86_64.tar.gz

    ```bash
    [root@ip-172-31-63-184 ~]# tar xvzf functionbeat-7.2.0-linux-x86_64.tar.gz
    functionbeat-7.2.0-linux-x86_64/NOTICE.txt
    functionbeat-7.2.0-linux-x86_64/fields.yml
    functionbeat-7.2.0-linux-x86_64/LICENSE.txt
    functionbeat-7.2.0-linux-x86_64/kibana/
    functionbeat-7.2.0-linux-x86_64/functionbeat
    functionbeat-7.2.0-linux-x86_64/.build_hash.txt
    functionbeat-7.2.0-linux-x86_64/functionbeat.reference.yml
    functionbeat-7.2.0-linux-x86_64/pkg/functionbeat
    functionbeat-7.2.0-linux-x86_64/README.md
    functionbeat-7.2.0-linux-x86_64/functionbeat.yml
    ```
6. veirfy extract has functionbeat.yml

    ```bash
    [root@ip-172-31-63-184 ~]# ls
    functionbeat-7.2.0-linux-x86_64  functionbeat-7.2.0-linux-x86_64.tar.gz
    [root@ip-172-31-63-184 ~]# 
    [root@ip-172-31-63-184 ~]# cd functionbeat-7.2.0-linux-x86_64/
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# ls
    fields.yml  functionbeat  functionbeat.reference.yml  `functionbeat.yml`  kibana  LICENSE.txt  NOTICE.txt  pkg  README.md
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]#
    ```

7. Create aws credentials file in root

    ```sh
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# cat ~/credentials.md
    export AWS_ACCESS_KEY_ID=AKIAIIMCMBUCW3IT4SIQ
    export AWS_SECRET_ACCESS_KEY=xxxx
    export AWS_DEFAULT_REGION=us-east-1

    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]#
    ```

    source file:
    $ source ~/credentials.md

    verify:
    $ printenv

8. configure functionbeat

    https://www.elastic.co/guide/en/beats/functionbeat/current/elasticsearch-output.html

    $ vi functionbeat-7.2.0-linux-x86_64/functionbeat.yml

#============================  Provider ===============================
functionbeat.provider.aws.deploy_bucket: "functionbeat-lambdalog-deploy"
functionbeat.provider.aws.functions:
  - name: cloudwatch
    enabled: true
    type: cloudwatch_logs
    description: "lambda function for cloudwatch logs"
    triggers:
      - log_group_name: /aws/lambda/activityStreamLambda
#==================== Elasticsearch template setting ==========================
setup.template.settings:
  index.number_of_shards: 1
#================================ Outputs =====================================
output.elasticsearch:
  hosts: ["3.213.192.20:9200"]
  enabled: true
#================================ Processors =====================================
processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_fields:
      target: project
      fields:
        name: insights-lambda

#================================ Logging =====================================
logging.level: debug


## full file:


```bash    
###################### Functionbeat Configuration Example #######################

# This file is an example configuration file highlighting only the most common
# options. The functionbeat.reference.yml file from the same directory contains all the
# supported options with more comments. You can use it as a reference.
#
# You can find the full configuration reference here:
# https://www.elastic.co/guide/en/beats/functionbeat/index.html
#

#============================  Provider ===============================
# Configure functions to run on AWS Lambda, currently we assume that the credentials
# are present in the environment to correctly create the function when using the CLI.
#
# Configure which S3 bucket we should upload the lambda artifact.
functionbeat.provider.aws.deploy_bucket: "functionbeat-lambdalog-deploy"

functionbeat.provider.aws.functions:
  # Define the list of function availables, each function required to have a unique name.
  # Create a function that accepts events coming from cloudwatchlogs.
  - name: cloudwatch
    enabled: true
    type: cloudwatch_logs

    # Description of the method to help identify them when you run multiples functions.
    description: "lambda function for cloudwatch logs"

    # Concurrency, is the reserved number of instances for that function.
    # Default is 5.
    #
    # Note: There is a hard limit of 1000 functions of any kind per account.
    #concurrency: 5

    # The maximum memory allocated for this function, the configured size must be a factor of 64.
    # There is a hard limit of 3008MiB for each function. Default is 128MiB.
    #memory_size: 128MiB

    # Dead letter queue configuration, this must be set to an ARN pointing to a SQS queue.
    #dead_letter_config.target_arn:

    # Execution role of the function.
    # role: arn:aws:iam::219708553334:role/functionbeat-role

    # Connect to private resources in an Amazon VPC.
    # virtual_private_cloud:
      # security_group_ids: ["sg-1838b463"]
      # subnet_ids: ["subnet-154d1c28", "subnet-956304cd"]

    # Optional fields that you can specify to add additional information to the
    # output. Fields can be scalar values, arrays, dictionaries, or any nested
    # combination of these.
    #fields:
    #  env: staging

    # List of cloudwatch log group registered to that function.
    triggers:
      - log_group_name: /aws/lambda/activityStreamLambda
    #    filter_pattern: mylog_

    # Define custom processors for this function.
    #processors:
    #  - dissect:
    #      tokenizer: "%{key1} %{key2}"


#==================== Elasticsearch template setting ==========================

setup.template.settings:
  index.number_of_shards: 1
  #index.codec: best_compression
  #_source.enabled: false


# Starting with Beats version 6.0.0, the dashboards are loaded via the Kibana API.
# This requires a Kibana endpoint configuration.
setup.kibana:

  # Kibana Host
  # Scheme and port can be left out and will be set to the default (http and 5601)
  # In case you specify and additional path, the scheme is required: http://localhost:5601/path
  # IPv6 addresses should always be defined as: https://[2001:db8::1]:5601
  #host: "localhost:5601"

  # Kibana Space ID
  # ID of the Kibana Space into which the dashboards should be loaded. By default,
  # the Default Space will be used.
  #space.id:

#============================= Elastic Cloud ==================================

# These settings simplify using functionbeat with the Elastic Cloud (https://cloud.elastic.co/).

# The cloud.id setting overwrites the `output.elasticsearch.hosts` and
# `setup.kibana.host` options.
# You can find the `cloud.id` in the Elastic Cloud web UI.
#cloud.id:

# The cloud.auth setting overwrites the `output.elasticsearch.username` and
# `output.elasticsearch.password` settings. The format is `<user>:<pass>`.
#cloud.auth:

#================================ Outputs =====================================

# Configure what output to use when sending the data collected by the beat.

#-------------------------- Elasticsearch output ------------------------------
output.elasticsearch:
  # Array of hosts to connect to.
  hosts: ["3.213.192.20:9200"]
  enabled: true
  # Optional protocol and basic auth credentials.
  #protocol: "https"
  #username: "elastic"
  #password: "changeme"

#----------------------------- Logstash output --------------------------------
#output.logstash:
  # The Logstash hosts
  #hosts: ["localhost:5044"]

  # Optional SSL. By default is off.
  # List of root certificates for HTTPS server verifications
  #ssl.certificate_authorities: ["/etc/pki/root/ca.pem"]

  # Certificate for SSL client authentication
  #ssl.certificate: "/etc/pki/client/cert.pem"

  # Client Certificate Key
  #ssl.key: "/etc/pki/client/cert.key"

#================================ Processors =====================================

# Configure processors to enhance or manipulate events generated by the beat.

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_fields:
      target: project
      fields:
        name: insights-lambda

#================================ Logging =====================================

# Sets log level. The default log level is info.
# Available log levels are: error, warning, info, debug
logging.level: debug

# At debug level, you can selectively enable logging only for some components.
# To enable all selectors use ["*"]. Examples of other selectors are "beat",
# "publish", "service".
#logging.selectors: ["*"]

#============================== Xpack Monitoring ===============================
# functionbeat can export internal metrics to a central Elasticsearch monitoring
# cluster.  This requires xpack monitoring to be enabled in Elasticsearch.  The
# reporting is disabled by default.

# Set to true to enable the monitoring reporter.
#monitoring.enabled: false

# Uncomment to send the metrics to Elasticsearch. Most settings from the
# Elasticsearch output are accepted here as well.
# Note that the settings should point to your Elasticsearch *monitoring* cluster.
# Any setting that is not set is automatically inherited from the Elasticsearch
# output configuration, so if you have the Elasticsearch output configured such
# that it is pointing to your Elasticsearch monitoring cluster, you can simply
# uncomment the following line.
#monitoring.elasticsearch:

#================================= Migration ==================================

# This allows to enable 6.7 migration aliases
#migration.6_to_7.enabled: true
```

9. deploy functionbeat

    ```bash
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# pwd
    /root/functionbeat-7.2.0-linux-x86_64
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# ./functionbeat deploy cloudwatch
    ```

    DEBUG: if cloud formation stack that automatically deplys this fails just delete stack in console
        https://console.aws.amazon.com/cloudformation/> select stack> delete stack
        ```sh
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# ./functionbeat deploy cloudwatch
    Function: cloudwatch, could not deploy, error: AlreadyExistsException: Stack [fnb-cloudwatch-stack] already exists
        status code: 400, request id: 0dc334b7-a1b5-11e9-9ff2-2d5b755700ca
    Fail to deploy 1 function(s)
        ```

    in ec2 sshed instance see if s3 bucket exist: 
    $ aws s3 ls

    DEBUG: 
    ```sh
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]# ./functionbeat deploy cloudwatch
    Function: cloudwatch, could not deploy, error: failed to create the stack
    Fail to deploy 1 function(s)
    [root@ip-172-31-63-184 functionbeat-7.2.0-linux-x86_64]#
    ```

    Now in https://console.aws.amazon.com/cloudformation/ select stack and check events tab to see which event failed to debug.
    `AWSLogs Resource Limit Exceeded - serverless `cloudwatchLog` event
    Reason: cloudwatch logs allow only 1 subscription filter per group https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch_limits_cwl.html

    I just deleted manually existing subscription.


    You can check stack console events for debug:

    ![out](./img/out8.png)

10.  Now you should see in cloudewatch logs console the subscription :

    Log Groups                              Insights    Expire Events After     Metric Filters      Subscriptions
    /aws/lambda/activityStreamLambda        Explore     2 weeks (14 days)       0 filters           Lambda (cloudwatch)

`Now in lambda functions you should see a lambda called cloudwatch `
https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/cloudwatch?tab=graph

![out](./img/out5.png)
11. To stop deployment and remove subscription:
    $ ./functionbeat remove cloudwatch


12. for updates to functionbeat.yml:

make and save change to functionbeat.yml
then:
`$ ./functionbeat update cloudwatch`

13. verify event come to kibana:

in playground sns > pubilsh message> 

```json
{
    "memberId": 1,
    "activityDate": "2019-04-25T17:52:30.459   Z",
    "activityDescription": "Completed enrollment form",
    "activityType": "CompletedEnrollementForm",
    "deviceName": null,
    "activityUrl": null,
    "calories": 0,
    "steps": 0,
    "stepType": null,
    "cumulativeStepsForDay": null,
    "dataCollectionMethod": null,
    "duration": null,
    "durationInSeconds": 0,
    "distance": null,
    "activeMinutes": 0,
    "rowId": null,
    "badgeUrl": null,
    "weight": null,
    "mood": null,
    "accomplished": true,
    "rewardsCurrency": null,
    "rewardsEarned": 0,
    "manuallyEntered": false,
    "createdDate": null,
    "amount": 0,
    "entityId": null,
    "height": null,
    "bmi": null,
    "bloodPressureSystolic": null,
    "bloodPressureDiastolic": null,
    "bloodPressurePulse": null,
    "cholesterolTotal": null,
    "glucoseFasting": null,
    "bodyFat": null,
    "a1c": null,
    "waistCircumference": null,
    "hipCircumference": null,
    "memberDate": null,
    "localStartDate": null,
    "localEndDate": null,
    "cholesterolHDL": null,
    "cholesterolLDL": null,
    "cholesterolTriglyceride": null,
    "glucoseNonFasting": null,
    "rewardable": true,
    "energyBurned": null,
    "energyBurnedGoal": null,
    "exerciseTime": null,
    "exerciseTimeGoal": null,
    "standMinutes": null,
    "standMinutesGoal": null,
    "manualAsValidated": false
}
```

Now activityStreamLambda kicks in and places json in dynamodb. veirfy its there. 

Now logs created in activityStreamLambda should trigger the new cloudwatch lambda created.  so there should be logs for the new cloudwatch lambda:

![out](./img/out6.png)

Now you should see recor in elastic search:
```sh
[root@ip-172-31-62-80 ~]# sudo curl -XGET 'http://3.213.192.20:9200/_cat/indices?v&pretty'
health status index                         uuid                   pri rep docs.count docs.deleted store.size pri.store.size

yellow open   `functionbeat-7.2.0-2019.07.10 9yxPz0MkR96IrR-kkgjcEQ`   1   1         13            0     37.9kb         37.9kb
```


and kibana:

(create index func*)
![out](./img/out7.png)


#### successful post to elasticsearch:
![out](./img/out9.png)


# Dockerfile for functionbeat

create local dir structure;
functionbeat 
    -| config
        |- functionbeat.yml
    -| Dockerfile


### functionbeat.yml
```sh

#============================  Provider ===============================
functionbeat.provider.aws.deploy_bucket: "functionbeat-lambdalog-deploy"
functionbeat.provider.aws.functions:
  - name: cloudwatchlogs
    enabled: true
    type: cloudwatch_logs
    description: "lambda function for cloudwatch logs"
    triggers:
      - log_group_name: /aws/lambda/activityStreamLambda

#==================== Elasticsearch template setting ==========================
setup.template.settings:
  index.number_of_shards: 1

#================================ Outputs =====================================
output.elasticsearch:
  hosts: [$HOSTS]
  enabled: true

#================================ Processors =====================================
processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_fields:
      target: project
      fields:
        name: insights-lambda


#================================ Logging =====================================
logging.level: debug
```


Ref: https://www.elastic.co/guide/en/beats/functionbeat/6.7/using-environ-vars.html

You can specify complex objects, such as lists or dictionaries, in environment variables by using a JSON-like syntax.

As with JSON, dictionaries and lists are constructed using {} and []. But unlike JSON, the syntax allows for trailing commas and slightly different string quotation rules. Strings can be unquoted, single-quoted, or double-quoted, as a convenience for simple settings and to make it easier for you to mix quotation usage in the shell. 

Arrays at the top-level do not require brackets ([]).

For example, the following environment variable is set to a `list`:

```json
ES_HOSTS="10.45.3.2:9220,10.45.3.1:9230"
```


You can reference this variable in the config file:

```json
output.elasticsearch:
  hosts: '${ES_HOSTS}'
```

When Functionbeat loads the config file, it resolves the environment variable and replaces it with the specified list before reading the hosts settin


### Dockerfile
```sh
#FROM alpine:3.7
FROM ubuntu:14.04

# source aws configuration
ARG aws_access_key_id
ENV AWS_ACCESS_KEY_ID=$aws_access_key_id
ARG aws_secret_access_key
ENV AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
ARG aws_default_region
ENV AWS_DEFAULT_REGION=$aws_default_region
ARG elasticsearch_hosts
ENV HOSTS=['$elasticsearch_hosts']

#RUN export AWS_ACCESS_KEY_ID=$aws_access_key_id
#RUN export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key
#RUN export AWS_DEFAULT_REGION=$aws_default_region
#RUN export HOSTS=$elasticsearch_hosts

# install curl
RUN apt-get update
RUN apt-get -y install curl


# download and extract functionbeat
RUN apt install curl
RUN curl -L -O https://artifacts.elastic.co/downloads/beats/functionbeat/functionbeat-7.2.0-linux-x86_64.tar.gz
RUN tar xvzf functionbeat-7.2.0-linux-x86_64.tar.gz

# copy configuration
COPY config/functionbeat.yml functionbeat-7.2.0-linux-x86_64/functionbeat.yml

# run functionbeat
WORKDIR "functionbeat-7.2.0-linux-x86_64"
CMD ./functionbeat deploy cloudwatch

```

### build image:

cd into directory containing dockerfile and run

```sh
docker build --build-arg aws_access_key_id=xxxx --build-arg aws_secret_access_key=xxxx --build-arg aws_default_region="us-east-1" --build-arg elasticsearch_hosts=3.213.192.20:9200  --build-arg elasticsearch_index="playground-applications" --build-arg bucket_name="functionbeat-lambdalog-deploy-playground" --build-arg aws_account_id="219708553334" --build-arg security_group_ids="sg-1838b463"  --build-arg subnet_ids="subnet-154d1c28,subnet-956304cd" -t functionbeat .
```


### create and run image container

docker stop functionbeat; docker rm functionbeat
docker rmi functionbeat

`$ docker run --name functionbeat functionbeat`

Now you should see deployed cloudwatch lambda and the subscription to activityStream log stream

### run functionbeat command
list help:
`$ docker run functionbeat ./functionbeat --help `

remove :
`$ docker run functionbeat ./functionbeat remove cloudwatch`


### debug docker run.sh
run.sh
```sh
#!/usr/bin/env bash
#./functionbeat update cloudwatch || ./functionbeat deploy cloudwatch

sucess=false

output=$(./functionbeat update cloudwatch)

if echo output | grep -q "ValidationError: No updates are to be performed"; then
    sucess=true
    echo "cloudwatch functionbeat already up-to-date"
elif echo output | grep -q "ValidationError: Stack [fnb-cloudwatch-stack] does not exist"; then
    output = $(./functionbeat deploy cloudwatch)
    if echo output | grep -q "deploy successful"; then
        sucess=true
        output "cloudwatch functionbeat deployed"
    fi
else
     echo "something went wrong: ", $output
fi

echo "success:" $suces
```


(base)  rdissanayakam@RBH12855  ~/vp/gitlab/erewhon/functionbeat   functionbeat ●✚  `docker run functionbeat  `                       
fail to deploy 1 function(s)
something went wrong: , Function: cloudwatch, could not update, error: ValidationError: No updates are to be performed. status code: 400, request id: 09de30b8-a4d0-11e9-be17-73c8d11b0605
success: false
(base)  rdissanayakam@RBH12855  ~/vp/gitlab/erewhon/functionbeat   functionbeat ●✚  docker ps -a | grep func                        
986dcce26736        functionbeat                                          "/bin/sh -c 'sh ./ru…"   2 minutes ago       Exited (0) About a minute ago                                                                                                           gallant_sinoussi
(base)  rdissanayakam@RBH12855  ~/vp/gitlab/erewhon/functionbeat   functionbeat ●✚  `docker start gallant_sinoussi`
gallant_sinoussi
(base)  ✘ rdissanayakam@RBH12855  ~/vp/gitlab/erewhon/functionbeat   functionbeat ●✚  d`ocker exec -it gallant_sinoussi bash    `
root@986dcce26736:/functionbeat-7.2.0-linux-x86_64# `ls`
LICENSE.txt  NOTICE.txt  README.md  data  fields.yml  functionbeat  functionbeat.reference.yml  functionbeat.yml  kibana  logs  pkg  run.sh
root@986dcce26736:/functionbeat-7.2.0-linux-x86_64# output=$(./functionbeat update cloudwatch)



## Errors


### try to deploy when /aws/lambda/activityStreamlambda (input logstream) does not exist

Fail to deploy 1 function(s)
Function: cloudwatch, could not deploy, error: failed to create the stack
complete deploying cloudwatch lambda

### try to deploy when cloudwatch stack already exist (deployed before)
Function: cloudwatch, could not deploy, error: AlreadyExistsException: Stack [fnb-cloudwatch-stack] already exists
	status code: 400, request id: 2bc27a50-a73d-11e9-bd32-a5f4266302d2
Fail to deploy 1 function(s)
complete deploying cloudwatch lambda


### try yo update when not cloudwatch stack does not exist (not deployed before)

fail to deploy 1 function(s)
Function: cloudwatch, could not update, error: ValidationError: Stack [fnb-cloudwatch-stack] does not exist
	status code: 400, request id: 034a2d8a-a73c-11e9-80ea-391c7d95c316
Fail to deploy 1 function(s)

### try to update when there are no updates
fail to deploy 1 function(s)
Function: cloudwatch, could not update, error: ValidationError: No updates are to be performed.
	status code: 400, request id: 2bc7408f-a7d2-11e9-8353-c32466e03c9b  

### try to update but cloudwatch stack in rolledback state
Function: cloudwatch, could not update, error: ValidationError: Stack:arn:aws:cloudformation:us-east-1:219708553334:stack/fnb-cloudwatch-stack/05a8b690-a73c-11e9-83f3-12d99c723360 is in ROLLBACK_COMPLETE state and can not be updated.
	status code: 400, request id: 2951efbd-a73d-11e9-b392-45c325678c6a
fail to deploy 1 function(s)

reason: look at the events in cloudformation stack:

The role defined for the function cannot be assumed by Lambda. (Service: AWSLambdaInternal; Status Code: 400; Error Code: InvalidParameterValueException; Request ID: ec2aa631-08ad-4cc4-8586-bd54b8bbdc2c)

A delete of stack deletes the lambda role


## Dockerfile you can install aws cli and run aws commands:


`$ aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/activityStreamLambda"`
{
    "logGroups": [
        {
            "arn": "arn:aws:logs:us-east-1:219708553334:log-group:/aws/lambda/activityStreamLambda:*", 
            "creationTime": 1563221619494, 
            "metricFilterCount": 0, 
            "logGroupName": "/aws/lambda/activityStreamLambda", 
            "storedBytes": 0
        }
    ]
}

`$ aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/activityStreamLambda2"`

{
    "logGroups": []
}

## cloudformation stack:

`aws cloudformation describe-stacks --stack-name fnb-cloudwatch-stack`
{
    "Stacks": [
        {
            "StackId": "arn:aws:cloudformation:us-east-1:219708553334:stack/fnb-cloudwatch-stack/e191b690-a7d0-11e9-a3b7-121b5b00f9e8",
            "StackName": "fnb-cloudwatch-stack",
            "CreationTime": "2019-07-16T13:51:59.186Z",
            "RollbackConfiguration": {},
            "StackStatus": "CREATE_COMPLETE",
            "DisableRollback": false,
            "NotificationARNs": [],
            "Capabilities": [
                "CAPABILITY_NAMED_IAM"
            ],
            "Tags": [],
            "EnableTerminationProtection": false
        }
    ]
}

`aws cloudformation describe-stacks --stack-name fnb-cloudwatch-stack2-non-existing`

An error occurred (ValidationError) when calling the DescribeStacks operation: Stack with id fnb-cloudwatch-stack2 does not exist


# use aws cli

if you have a profile for a aws account in ~/.aws/credentials:
(base)  rdissanayakam@RBH12855  ~/vp  cat ~/.aws/credentials 
[default]
aws_access_key_id = xxxx
aws_secret_access_key = xxxx

[playground]
aws_access_key_id = xxxx
aws_secret_access_key = xxxx

[qagitlab]
`aws_access_key_id = xxxx
`aws_secret_access_key = xxxx`

Now you can specify profile and region to run commands in that aws account without having to export any keys:

`aws logs describe-log-groups --profile qagitlab --region "us-east-1"`

```json
{
    "logGroups": [
        {
            "logGroupName": "/aws/lambda/activityStreamLambda",
            "creationTime": 1559574028442,
            "metricFilterCount": 0,
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/activityStreamLambda:*",
            "storedBytes": 54485919789
        },
        {
            "logGroupName": "/aws/lambda/cloudwatch",
            "creationTime": 1563457691444,
            "metricFilterCount": 0,
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:*",
            "storedBytes": 0
        }
    ]
}

```

view log streams in aws/lambda/cloudwatch logstreams:

`aws logs describe-log-streams --log-group-name /aws/lambda/cloudwatch  --profile qagitlab --region "us-east-1"`

```json
{
    "logStreams": [
        {
            "logStreamName": "2019/07/18/[$LATEST]1c7eb80068b04e4785ee36c2c52107a6",
            "creationTime": 1563463290187,
            "firstEventTimestamp": 1563463292304,
            "lastEventTimestamp": 1563463292304,
            "lastIngestionTime": 1563464119149,
            "uploadSequenceToken": "49597108459857708445888670258489252953444985484909881474",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]1c7eb80068b04e4785ee36c2c52107a6",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]20bcb3c0ccdd4c9eae0d0fbe39d2c1ce",
            "creationTime": 1563463290212,
            "firstEventTimestamp": 1563463292162,
            "lastEventTimestamp": 1563463292162,
            "lastIngestionTime": 1563464118961,
            "uploadSequenceToken": "49597124621207753821046875876469688693968748011181179458",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]20bcb3c0ccdd4c9eae0d0fbe39d2c1ce",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]2be30f4ab10f4e7eb9dad0153c2fe103",
            "creationTime": 1563457727989,
            "firstEventTimestamp": 1563457728915,
            "lastEventTimestamp": 1563463361814,
            "lastIngestionTime": 1563463361824,
            "uploadSequenceToken": "49597464168384614002961182721547714094624459578952562210",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]2be30f4ab10f4e7eb9dad0153c2fe103",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]3ee6d8a95ac8411498a55cd8bab80e40",
            "creationTime": 1563457728128,
            "firstEventTimestamp": 1563457729096,
            "lastEventTimestamp": 1563462944647,
            "lastIngestionTime": 1563463353843,
            "uploadSequenceToken": "49596895203451162687568998200904080691176482277761017282",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]3ee6d8a95ac8411498a55cd8bab80e40",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]4a1af33c001949ee90bde0fcfd1b9d13",
            "creationTime": 1563463290144,
            "firstEventTimestamp": 1563463292690,
            "lastEventTimestamp": 1563463711297,
            "lastIngestionTime": 1563464117404,
            "uploadSequenceToken": "49596804279544162339679056254223931068498803953192141234",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]4a1af33c001949ee90bde0fcfd1b9d13",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]775728d5d0bc457e88b987e114a7cf96",
            "creationTime": 1563457727990,
            "firstEventTimestamp": 1563457728947,
            "lastEventTimestamp": 1563463351594,
            "lastIngestionTime": 1563463351603,
            "uploadSequenceToken": "49597164569402357011681385699256019577984614593156502258",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]775728d5d0bc457e88b987e114a7cf96",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]7f01ac20f9ab4bdd94843bddf687994b",
            "creationTime": 1563457728075,
            "firstEventTimestamp": 1563457729058,
            "lastEventTimestamp": 1563462915576,
            "lastIngestionTime": 1563463352085,
            "uploadSequenceToken": "49597148102799711359049418256589390946717411633353069746",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]7f01ac20f9ab4bdd94843bddf687994b",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]d3f7a8d29bd84cad8dac1c998eb0e535",
            "creationTime": 1563463290042,
            "firstEventTimestamp": 1563463292099,
            "lastEventTimestamp": 1563463490813,
            "lastIngestionTime": 1563464117591,
            "uploadSequenceToken": "49596779053587915372591227432812526796506709955879093122",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]d3f7a8d29bd84cad8dac1c998eb0e535",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]d6c15e0a7d5345cb940cdec41fff282f",
            "creationTime": 1563457728137,
            "firstEventTimestamp": 1563457729100,
            "lastEventTimestamp": 1563462938672,
            "lastIngestionTime": 1563463360744,
            "uploadSequenceToken": "49597583964285896806512608661348517577311451405582002114",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]d6c15e0a7d5345cb940cdec41fff282f",
            "storedBytes": 0
        },
        {
            "logStreamName": "2019/07/18/[$LATEST]e1ccb90b8f5a40898813a244cf3f9d63",
            "creationTime": 1563463290200,
            "firstEventTimestamp": 1563463292545,
            "lastEventTimestamp": 1563463292545,
            "lastIngestionTime": 1563464118633,
            "uploadSequenceToken": "49597147888868662669544800575863167953362365475052729122",
            "arn": "arn:aws:logs:us-east-1:1234:log-group:/aws/lambda/cloudwatch:log-stream:2019/07/18/[$LATEST]e1ccb90b8f5a40898813a244cf3f9d63",
            "storedBytes": 0
        }
    ]
}

```

## view logstrem event :

`aws logs get-log-events --log-group-name '/aws/lambda/cloudwatch' --log-stream-name '2019/07/18/[$LATEST]1c7eb80068b04e4785ee36c2c52107a6'  --profile qagitlab --region "us-east-1" >1c7eb80068b04e4785ee36c2c52107a6.json`


## describe load balancers (list subnet id, security group)

`aws elb describe-load-balancers --profile qagitlab --region us-east-1`


find ip resolution: 10.3.x.x
`$ nslookup internal-ops-elasticsearch-1755344086.us-east-1.elb.amazonaws.com`
Server:		192.168.86.1
Address:	192.168.86.1#53

Non-authoritative answer:
Name:	internal-ops-elasticsearch-1755344086.us-east-1.elb.amazonaws.com
Address: 10.3.6.192
Name:	internal-ops-elasticsearch-1755344086.us-east-1.elb.amazonaws.com
Address: 10.3.7.184


find subnets of a vpc:

`aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-bccb26d8" --profile qagitlab --region us-east-1`

filtered by tags:
`rdissanayakam@rbh12855  ~/vp/aws_access_keys  aws ec2 describe-subnets  --filters Name=tag:group,Values=functionbeat --profile stagegitlab --region us-east-1`

```json
{
    "Subnets": [
        {
            "AvailabilityZone": "us-east-1a",
            "AvailableIpAddressCount": 11,
            "CidrBlock": "10.1.53.0/28",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": false,
            "State": "available",
            "SubnetId": "subnet-0d226e854c363d497",
            "VpcId": "vpc-29f3ce4c",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "stage-functionbeat-lambda-a-sub"
                },
                {
                    "Key": "group",
                    "Value": "functionbeat"
                },
                {
                    "Key": "env",
                    "Value": "stage"
                }
            ]
        },
        {
            "AvailabilityZone": "us-east-1b",
            "AvailableIpAddressCount": 11,
            "CidrBlock": "10.1.53.16/28",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": false,
            "State": "available",
            "SubnetId": "subnet-004f094a358f275cd",
            "VpcId": "vpc-29f3ce4c",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "stage-functionbeat-lambda-b-sub"
                },
                {
                    "Key": "env",
                    "Value": "stage"
                },
                {
                    "Key": "group",
                    "Value": "functionbeat"
                }
            ]
        }
    ]
}
```
(base)  rdissanayakam@rbh12855  ~/vp/aws_access_keys  

view security groups:

`aws ec2 describe-security-groups --filters Name=vpc-id,Values=vpc-29f3ce4c --profile stagegitlab --region us-east-1 `

`aws ec2 describe-security-groups --filters Name=group-name,Values=allow-functionbeat-sg --profile qagitlab --region=us-east-1`

```json
{
    "SecurityGroups": [
        {
            "Description": "Security group for lambda to move logs from cloudwatch to elasticsearch",
            "GroupName": "allow-functionbeat-sg",
            "IpPermissions": [],
            "OwnerId": "1234",
            "GroupId": "sg-0a0eaa390b0292fb4",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": [],
                    "UserIdGroupPairs": []
                }
            ],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "cloudwatch-functionbeat-lambda-sg"
                }
            ],
            "VpcId": "vpc-bccb26d8"
        }
    ]
}```
(base)  rdissanayakam@RBH12855  ~/vp/aws_access_keys  


`aws ec2 describe-security-groups --profile qagitlab --group-names allow-functionbeat-sg --region us-east-1`           
{
    "SecurityGroups": [
        {
            "Description": "Security group for lambda to move logs from cloudwatch to elasticsearch",
            "GroupName": "allow-functionbeat-sg",
            "IpPermissions": [],
            "OwnerId": "1234",
            "GroupId": "sg-0ac480210436baaa1",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": [],
                    "UserIdGroupPairs": []
                }
            ],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "cloudwatch-functionbeat-lambda-sg"
                }
            ],
            "VpcId": "vpc-7884611d"
        }
    ]
}

check if member id record exist in dynamodb table:

`aws dynamodb get-item --table-name healthy_habit_training --key '{"member_id": {"N": "1"}}'  --profile playgroundgitlab  --region us-east-1`
{
    "Item": {
        "member_id_mod1k": {
            "N": "1"
        },
        "member_id": {
            "N": "1"
        },
        "CompletedEnrollementForm": {
            "N": "5"
        }
    }
}
(base)  rdissanayakam@rbh12855  ~/vp  


# Elasticsearch behind a elastic load balancer in different vpc than cloudwatch lambda (SAME AWS ACCONT, DIFFERENT VPCs)

## bring up ec2 instance and install elasticsearch 

- Use readme above to do it.

- Create elastic ip > associate with instance to get a public ip.

- note down the vpc-id of elasticsearch ec2 instance

![out](./img/out10.png)

## Create elasticload balancer

Services > EC2 > Load Balancers in left pane 

# Purge queue

`aws sqs purge-queue --queue-url https://sqs.us-east-1.amazonaws.com/028037478894/STAGE_hh_recommender_training_activity_queue --profile stagegitlab --region=us-east-1`

Get started with New Relic Infrastructure

Begin your trial by following these simple steps to install the agent on an unlimited number of hosts!

Select platform:


Linux

Windows
Select installer:

yum
apt
zypper
yumAmazon Linux, CentOS, RHELaptDebian, Ubuntu
zypperSLES
Create a configuration file and add your license key

echo "license_key: xxxx" | sudo tee -a /etc/newrelic-infra.yml
You can add extra configurations that fine-tune your agent’s behavior and collect custom attributes.
Create the agent’s yum repository

Amazon Linux, CentOS 6, RHEL 6

sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/6/x86_64/newrelic-infra.repo
Amazon Linux 2, CentOS 7, RHEL 7

sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
CentOS 8, RHEL 8

sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/8/x86_64/newrelic-infra.repo
Update your yum cache

sudo yum -q makecache -y --disablerepo='*' --enablerepo='newrelic-infra'
Run the installation script

sudo yum install newrelic-infra -y
Get started

Wait a few seconds, and your data should begin appearing!

You can integrate with your Amazon Elastic Compute Cloud (Amazon EC2) account for dynamic-tagging and autoscaling properties


## run.py (Not used)

```python
#!/usr/bin/python
import time
import boto3
import subprocess
from botocore.exceptions import ClientError

cloudformation_client = boto3.client("cloudformation")
logs_client = boto3.client("logs")

LOG_GROUP_NAME="/aws/lambda/activityStreamLambda"
CLOUDFORMATION_STACK_NAME="fnb-cloudwatch-stack"



def update_functionbeat():
    subprocess_output=''
    try:
        #subprocess_output = subprocess.run(["./functionbeat", "-v", "-e",  "update", "cloudwatch", "capture_output=True"])
        #print("update output = "+str(subprocess_output))
        pipe = subprocess.Popen( './functionbeat -v -e -d "*" update cloudwatch', shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE )
        res = pipe.communicate()
        print("retcode =", pipe.returncode)
        print("res =", res)
        print("stderr =", res[1])
    except subprocess.CalledProcessError as e:
        print("Unexpected error in update_functionbeat return code: " + e.returncode + ", output:\n" + e.output)
    print("update completed!")


def deploy_functionbeat():
    subprocess_output=''
    try:
        subprocess_output = subprocess.run(["./functionbeat", "-v", "-e",  "deploy", "cloudwatch", "capture_output=True"])
        print("deployment output = "+str(subprocess_output))
    except subprocess.CalledProcessError as e:
        print("Unexpected error in update_functionbeat return code: " + e.returncode + ", output:\n" + e.output)
    print("deploy completed!")


def stack_exists_with_status(name, required_status = ["CREATE_COMPLETE",]):
    try:
        data = cloudformation_client.describe_stacks(StackName = name)
    except ClientError as e:
        print("Unexpected error in stack_exists_with_status: %s" % e)
        # if e.response['Error']['Code'] == 'EntityAlreadyExists':
        #     print("User already exists")
        # else:
        #     print("Unexpected error: %s" % e)
        return False
    return data["Stacks"][0]["StackStatus"] in required_status


def stack_in_failed_state(name):
    required_status = ["CREATE_FAILED", "DELETE_FAILED", "ROLLBACK_FAILED", "UPDATE_ROLLBACK_FAILED" ]
    return stack_exists_with_status(name, required_status)


def stack_in_inprogress_state(name):
    required_status = ["CREATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "REVIEW_IN_PROGRESS", "ROLLBACK_IN_PROGRESS", "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_IN_PROGRESS"]
    return stack_exists_with_status(name, required_status)


def stack_in_completed_state(name):
    required_status = ["CREATE_COMPLETE", "DELETE_COMPLETE", "ROLLBACK_COMPLETE", "UPDATE_COMPLETE", "UPDATE_ROLLBACK_COMPLETE"]
    return stack_exists_with_status(name, required_status)


def check_stack_exists(name):
    try:
        data = cloudformation_client.describe_stacks(StackName = name)
    except ClientError as e:
        print("Unexpected error in check_stack_exists: %s" % e)
        return False
    return True


def get_stack_status(name):
    try:
        data = cloudformation_client.describe_stacks(StackName = name)
    except ClientError as e:
        print("Unexpected error in get_stack_status: %s" % e)
        return "Stack Does Not Exist"
    return data["Stacks"][0]["StackStatus"]


def delete_stack(name):
    try:
        data = cloudformation_client.delete_stack(StackName = name)
    except ClientError as e:
        print("Unexpected error in delete_stack: %s" % e)
        return False
    return True


def wait_till_stack_deletion_completes(name):
    stack_delete_complete=False
    while True:
        exists = stack_exists(name)
        if(exists == False):
            stack_delete_complete=True
            break
        else:
            print("wating for delete completion...")
            time.sleep( 5 )
    return stack_delete_complete


def wait_till_stack_progress_completes(name):
    while True:
        exists = stack_exists(name)
        status  = get_stack_status(name)
        if (stack_exists_with_status("CREATE_IN_PROGRESS", "DELETE_IN_PROGRESS", "REVIEW_IN_PROGRESS", "ROLLBACK_IN_PROGRESS", "UPDATE_IN_PROGRESS", "UPDATE_ROLLBACK_COMPLETE_CLEANUP_IN_PROGRESS", "UPDATE_ROLLBACK_IN_PROGRESS")):
            print("wating for progrss state completion...")
            time.sleep( 5 )
        else:
            break


def check_log_group_exists(name):
    try:
        data = logs_client.describe_log_groups(logGroupNamePrefix=name)
    except ClientError as e:
        rint("Unexpected error in check_log_group_exists: %s" % e)
        return False
    return True

def main():
    # check cloudformation stack fnb-cloudwatch-stack exist
    stack_exists = check_stack_exists(CLOUDFORMATION_STACK_NAME)
    # check cloudformation stack fnb-cloudwatch-stack status
    stack_status =  get_stack_status(CLOUDFORMATION_STACK_NAME) if stack_exists == True else ""


    # if stack exist
    if (stack_exists) :
        print("checking if cloudformation stack in in_progress or failed state....")
        # if stack is in one of IN_PROGRESS status
        if (stack_in_inprogress_state(CLOUDFORMATION_STACK_NAME)):
            print("stack in IN_PROGRSS stage. waiting for completion.....")
            wait_till_stack_progress_completes(CLOUDFORMATION_STACK_NAME)   # wait for IN_PROGRESS to change status
        # if stack status is in one of  FAILED status
        if(stack_in_failed_state(CLOUDFORMATION_STACK_NAME) ):
            print("stack in IN_PROGRSS stage. waiting for deletion.....")
            delete_stack(CLOUDFORMATION_STACK_NAME)         # call delete stack
            wait_till_stack_deletion_completes(CLOUDFORMATION_STACK_NAME)         # verify deleted
            print("stack delete complete.")
        # else in COMPLETE state
            # continue
    else:
        print("no functionbeat cloudformation stacks found")


    # ckeck log group for activityStreamLambda exist
    log_group_exists = check_log_group_exists(LOG_GROUP_NAME)
    # check if stack exist
    stack_exists = check_stack_exists(CLOUDFORMATION_STACK_NAME)

    # if log group exists
    if (log_group_exists):
        print("log group exist!")
        # if stack exist
        if (stack_exists):
            print("stack exist!")
            # if stack is not in one in a failed or in progress state
            if (stack_in_completed_state(CLOUDFORMATION_STACK_NAME)):
                print("stack is in non-fail state. Attempting updating functionbeat...")
                # call update on functionbeat
                update_functionbeat()
        else:
            # call deploy on functionbeat
            print("no stack exist. Attempting deploying functionbeat...")
            deploy_functionbeat()
    else:
        print("log group does not exist")


if __name__ == '__main__':
    main()

```