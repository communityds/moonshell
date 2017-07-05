#
# AWS FUNCTION LOADING
#
for aws_file in $(find "${ENV_LIB}/aws/" ${ENV_FIND_OPTS} -name '*.sh'); do
    source ${aws_file}
done

# This is sensitive information. Set it as an array in profile.d/private/, this
# location is .gitignored
aws_accounts () {
    if [[ -z ${AWS_ACCOUNTS[@]-} ]]; then
        echoerr "ERROR: \${AWS_ACCOUNTS[@]} is unset."
        return 1
    else
        echo ${AWS_ACCOUNTS[@]}
    fi
}

