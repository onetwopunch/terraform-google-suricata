# Terraform Module for Suricata

This module sets up packet mirroring in a Google Cloud VPC and a collector instance behind an ILB, running Suricata IDS.

## Usage

See [example](./example) directory for  usage. This will setup a network, two subnets, packet mirroring and the Suricata instance, which collects packets from the other subnet.

```hcl
module "suricata" {
  source = "./terraform-google-suricata"

  project = var.project
  network = google_compute_network.ids.id
  subnet  = google_compute_subnetwork.ids.id
  zone    = "us-central1-a"
  target_subnets = [
    google_compute_subnetwork.test.id
  ]

  custom_rules_path = var.custom_rules_path
}
```

## Testing
To test that packet mirroring and Suricata are working properly, we'll create a simple rules file that triggers an alert on an innocuous event such as a DNS query. These alerts were taken from the [Qwiklab](https://www.qwiklabs.com/focuses/14864?parent=catalog) on this topic. 

### 1. Prerequisites

First create a bucket, it doesn't matter the name, using `gsutil mb $BUCKET`.

The upload the file [example/my.rules](./example/my.rules) into the bucket using:

```bash
gsutil cp example/my.rules gs://$BUCKET
```

### 2. Terraform
Next, create a file called `terraform.tfvars` in the [`example`](./example) directory. And copy this, replacing the placeholder values:
```
project = "MY_PROJECT_NAME"
custom_rules_path = "gs://MY_BUCKET_NAME/my.rules"
```

Now run `terraform apply`.

### 3. Testing Suricata

To verify packet mirroring and Suricata is working properly, let's open one terminal and SSH into the `test` instance we created. The command should look similar to this, assuming your project has been set by `gcloud config set project ...`:

```
gcloud compute ssh test --zone us-central1-a --tunnel-through-iap
```

Now in a new terminal, let's SSH into our Suricata collector instance.

```
gcloud compute instances list | grep suricata
# This should output the name of the instance
gcloud compute ssh SURICATA_INSTANCE_NAME --zone us-central1-a --tunnel-through-iap
```

Once in your Suricata instance, you first should tail the fast.log. We'll see an alert here in a moment.

```bash
# Suricata Instance
tail -f /var/log/suricata/fast.log
```

Now back in your test instance, let's make a DNS request:

```bash
# Test instance
sudo apt install dnsutils
dig @8.8.8.8 example.com
```

In your Suricata terminal (in your fast.log) you should see the alert show up immediately, something like this:
```
03/22/2021-21:05:17.558245  [**] [1:99996:1] BAD UDP DNS REQUEST [**] [Classification: (null)] [Priority: 3] {UDP} 172.21.1.3:55787 -> 8.8.8.8:53
```

Now that you verified that packet mirroring and Suricata are working correctly, you can verify the connection to Cloud Logging is setup by going to the Cloud Logging Logs viewer in the GCP console, and running the following query:

```
logName:"logs/suricata.fast"
```

You should have at least one entry. Now you have your Suricata alerts in Cloud Logging so you can eventually make alerts using Cloud Monitoring and get pestered by Pagerduty or whatever, when Suricata thinks you're being attacked!

## Providers

| Name | Version |
|------|---------|
| google | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:-----:|
| base\_priority | To make the IDS work with packet mirroring, we need to allow all ports access. However, we still don't want to allow SSH from anyhere.<br>To solve this, we have 3 firewall rules with increasing priority. The first allows all access, the second denies SSH, the third allows<br>SSH only from the IAP range. This value is the base priority, which is incremented for each rule. | `number` | `1000` | no |
| custom\_rules\_path | GCS bucket path for Suricata .rules file. i.e gs://my-bucket/my.rules | `string` | `""` | no |
| enable\_eve\_export | If true, logs from /var/log/suricata/eve.json will be parsed and sent to Cloud Logging. Note that these are much more chatty and include stats and traffic. | `bool` | `false` | no |
| enable\_fast\_export | If true, logs from /var/log/suricata/fast.log will be parsed and sent to Cloud Logging. These only include alerts. | `bool` | `true` | no |
| filter | Filter configuration for packet mirroring | <pre>object({<br>    ip_protocols = list(string)<br>    cidr_ranges  = list(string)<br>    direction    = string<br>  })<br></pre> | <pre>{<br>  "cidr_ranges": [<br>    "0.0.0.0/0"<br>  ],<br>  "direction": "BOTH",<br>  "ip_protocols": [<br>    "tcp",<br>    "udp",<br>    "icmp"<br>  ]<br>}<br></pre> | no |
| network | Self link of the network on which Suricata will be deployed and will monitor | `string` | n/a | yes |
| prefix | Prefix of all resource names | `string` | `"suricata"` | no |
| project | Project Id for the resources | `string` | n/a | yes |
| region | Region for Suricata. Must match the zone of the subnet | `string` | `"us-central1"` | no |
| subnet | Self link of the subnet on which Suricata will be deployed | `string` | n/a | yes |
| suricata\_config\_path | A file path to a suricata.yaml file that you would like to override the default. | `string` | `""` | no |
| target\_instances | Target instances that will be mirrored | `list(string)` | `[]` | no |
| target\_subnets | Target subnets that will be mirrored | `list(string)` | `[]` | no |
| target\_tags | Target tags that will be mirrored | `list(string)` | <pre>[<br>  "use-suricata"<br>]<br></pre> | no |
| zone | Zone for Suricata. Must match the zone of the subnet | `string` | `"us-central1-a"` | no |

## Outputs

No output.

