# M2 Communication and Deployment Status

Updated: 2026-10-11. Only the state bucket is verified deployed. Networking
is implemented and planned; host, application, and supporting modules remain
future work. Dashed links describe planned communication.

```mermaid
flowchart TB
  operator[Operator / Ansible controller]
  client[Browser / API client]
  dns[Route 53: phoniex.site - existing zone verified]
  state[S3 Terraform state bucket - deployed]
  transfer[S3 Ansible transfer bucket - planned]
  ssm[AWS Systems Manager - planned host registration]
  secrets[Parameter Store SecureString - planned]
  cw[CloudWatch logs and monitoring - planned]

  subgraph aws[AWS us-east-2]
    state
    transfer
    ssm
    secrets
    cw
    subgraph vpc[VPC 10.42.0.0/16 - implementation planned]
      igw[Internet gateway + explicit public route - planned]
      subgraph subnet[public_a 10.42.1.0/24 / us-east-2a - planned]
        eip[Elastic IP + application security group - planned]
        subgraph host[Ubuntu EC2 / SSM only - planned]
          caddy[Caddy: HTTPS frontend and API]
          frontend[Lago frontend]
          api[Lago API]
          worker[Lago worker]
          scheduler[Lago scheduler]
          pg[PostgreSQL]
          redis[Redis]
          pdf[PDF service]
          data[Encrypted EBS persistent data]
          certs[Persistent Caddy certificate data]
        end
      end
    end
  end

  operator -->|Terraform state + native S3 lock| state
  client -. DNS lookup .-> dns
  client -. HTTPS .-> igw
  igw -.-> eip
  eip -. ports 80/443 .-> caddy
  caddy -.-> frontend
  caddy -.-> api
  api -.-> pg
  api -.-> redis
  worker -.-> pg
  worker -.-> redis
  scheduler -.-> redis
  worker -.-> pdf
  pg -.-> data
  redis -.-> data
  api -.-> data
  worker -.-> data
  caddy -.-> certs
  operator -. administration .-> ssm
  host -. outbound management .-> ssm
  operator -. module transfers .-> transfer
  host -. presigned transfers .-> transfer
  host -. chosen retrieval identity TBD .-> secrets
  host -. logs and metrics .-> cw
```

The exact pinned Compose dependencies and secret-retrieval identity will be
verified in their respective checkpoints. DNS is a lookup path. SSH, private
subnets, NAT, ALB, managed PostgreSQL/Redis, and a second host are deferred.
