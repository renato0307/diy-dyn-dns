data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "build/bin/app"
  output_path = "build/bin/app.zip"
}

resource "random_id" "unique_suffix" {
  byte_length = 2
}
