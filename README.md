# rds-instance-from-snapshot

A lightweight desktop GUI for restoring AWS RDS instances from snapshots. Select a region, pick an instance, choose a snapshot, enter a new instance name, and restore — inheriting the original instance's subnet group, security groups, parameter group, and CA certificate.

Built with [glimmer-dsl-libui](https://github.com/AndyObtiva/glimmer-dsl-libui).

## Requirements

- Ruby 3.3+
- AWS credentials configured via any standard method (environment variables, `~/.aws/credentials`, IAM instance profile, etc.)

### IAM Permissions

The following permissions are required:

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeRegions",
    "rds:DescribeDBInstances",
    "rds:DescribeDBSnapshots",
    "rds:RestoreDBInstanceFromDBSnapshot"
  ],
  "Resource": "*"
}
```

## Install & Run

```sh
bundle install
ruby app.rb
```

## Usage

1. Select an AWS region from the dropdown (defaults to `us-east-1`)
2. Click an RDS instance from the list to load its snapshots
3. Click a snapshot to select it
4. Enter a name for the new instance
5. Click **Restore**

The restore request inherits the source instance's subnet group, security groups, parameter group, and CA certificate. Multi-AZ is disabled on the restored instance.

Logs are written to `log/app.log`.
