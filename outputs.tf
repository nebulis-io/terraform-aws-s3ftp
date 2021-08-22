output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "ftp_ip" {
  value = aws_eip.this.public_ip
}
