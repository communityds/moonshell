#
# SECURITY TOKEN SERVICE FUNCTIONS
#
sts_account_id () {
    aws sts get-caller-identity --query "Account" --output text
    return $?
}
