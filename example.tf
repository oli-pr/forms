provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

/*
resource "aws_vpc" "default" {

  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"

  tags {
    project = "twitter"
  }

}
*/

resource "aws_security_group" "twitter_ingress" {
  name = "vpc_twitter_ingress"
  description = "Allow ssh traffic"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${var.my_ip}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

//  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_s3_bucket" "tweetbucket" {
  bucket = "archimage-solutions.twitter.tweets"
  acl = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags {
    project = "twitter"
  }
}

resource "aws_iam_role" "tweets_iam_role" {
  name = "tweets_iam_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
              "Service": [
                "ec2.amazonaws.com"
              ]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role" "kinesis_ingest_iam_role" {
  name = "kinesis_ingest_iam_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
              "Service": [
                "ec2.amazonaws.com"
              ]
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "kinesis_ingest_ec2_profile" {
   name = "kinesis_ingest_ec2_profile"
   role = "kinesis_ingest_iam_role"
}

resource "aws_iam_instance_profile" "tweets_ec2_profile" {
   name = "tweets_ec2_profile"
   role = "tweets_iam_role"
}

resource "aws_iam_role_policy" "tweets_iam_role_policy" {
   name = "tweets_iam_role_policy"
   role = "${aws_iam_role.tweets_iam_role.id}"
   policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:PutRecord"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "kinesis_ingest_iam_role_policy" {
   name = "kinesis_ingest_iam_role_policy"
   role = "${aws_iam_role.kinesis_ingest_iam_role.id}"
   policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:DescribeStream",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
	"dynamodb:*",
	"cloudwatch:PutMetricData",
        "s3:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_kinesis_stream" "tweet_stream" {
  name             = "tweet_stream"
  shard_count      = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  tags {
    Environment = "test"
  }
}

resource "aws_instance" "twitter_api_scrape" {
  ami           = "ami-26ebbc5c" // RHEL 7.4
//  ami           = "ami-2757f631" Ubuntu
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.tweets_ec2_profile.id}"
  key_name = "banana"
  vpc_security_group_ids = ["${aws_security_group.twitter_ingress.id}"]

  tags {
    project = "twitter"
  }
}

resource "aws_instance" "example" {
  ami           = "ami-26ebbc5c" // RHEL 7.4
//  ami           = "ami-2757f631" Ubuntu
  instance_type = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.kinesis_ingest_ec2_profile.id}"
  key_name = "banana"
  vpc_security_group_ids = ["${aws_security_group.twitter_ingress.id}"]

  tags {
    project = "twitter"
  }
}
