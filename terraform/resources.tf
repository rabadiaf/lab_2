resource "aws_instance" "ec2-A" {
  ami           = "ami-12345"
  instance_type = var.ec2_type
  tags = {
    Name = "ec2 lab A"
  }
}
resource "aws_instance" "ec2-B" {
  ami           = "ami-13247"
  instance_type = var.ec2_type
  tags = {
    Name = "ec2 lab B"
  }
}
resource "aws_s3_bucket" "my_s3" {
  bucket = var.my_bucket
}
resource "aws_s3_bucket" "gft_s3" {
  bucket = var.gft_s3
}
resource "aws_iam_user" "iam_user" {
  name = var.iam_name
}
