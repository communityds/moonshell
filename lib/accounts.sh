#
# ACCOUNT FUNCTIONS
#
production () {
    $(aws-creds production)
    aws-creds show
}

staging () {
    $(aws-creds staging)
    aws-creds show
}

development () {
    $(aws-creds development)
    aws-creds show
}

