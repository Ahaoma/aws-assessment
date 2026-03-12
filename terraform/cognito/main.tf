resource "aws_cognito_user_pool" "main" {
  name = "unleash-live-user-pool"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  auto_verified_attributes = ["email"]

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Project = "unleash-live-assessment"
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "unleash-live-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  generate_secret = false
}

resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.user_email

  attributes = {
    email          = var.user_email
    email_verified = "true"
  }

  # Temporary password – must be changed on first login.
  # The test script handles the NEW_PASSWORD_REQUIRED challenge.
  temporary_password   = "Temp1234!"
  message_action       = "SUPPRESS"
  force_alias_creation = false
}
