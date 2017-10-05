#
# SIMPLE STORAGE SERVICE (S3) FUNCTIONS
#
s3_stack_bucket_name () {
    # From the AWS::S3::Buckets defined in a stack, if there are multiple
    # buckets, prompt for selection and return a string of a single S3 bucket
    local stack_name=$1

    local -a s3_buckets=($(stack_resource_type ${stack_name} "AWS::S3::Bucket"))

    if [[ -z ${s3_buckets[@]-} ]]; then
        echoerr "ERROR: No S3 buckets found in stack '${stack_name}'"
        return 1
    elif [[ ${#s3_buckets[@]} -gt 1 ]]; then
        choose ${s3_buckets[@]}
        return $?
    else
        echo ${s3_buckets}
        return 0
    fi
}

s3_list_versions () {
    # Enumerate either latest, or archived versions of objects in a versioned
    # ${s3_bucket_name}. Returns VersionIds as an array
    local s3_bucket_name=$1
    # Parsing in $2 inverts the query from true (is latest) to false (is not latest)
    [[ ${2-} ]] \
        && local is_latest="false" \
        || local is_latest="true"

    aws s3api list-object-versions \
        --bucket ${s3_bucket_name} \
        --query "[Versions][?IsLatest==${is_latest}][].VersionId" \
        --output text
    return $?
}

s3_list_delete_markers () {
    # When an object is deleted a DeleteMarker is set. Enumerate all
    # DeleteMarkers and return VersionIds as an array
    local s3_bucket_name=$1

    aws s3api list-object-versions \
        --bucket ${s3_bucket_name} \
        --query "DeleteMarkers[].VersionId" \
        --output text
    return $?
}

s3_ls () {
    local stack_name=$1
    local location=${2-}

    # '//' is not a valid path in s3 land
    [[ ${location} =~ ^/$ ]] \
        && echoerr "ERROR: Location can not start with a '/'" \
        && return 1

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}/${location-}"
    echoerr "INFO: Listing objects in ${s3_url}"
    aws s3 ls ${s3_url}
    return $?
}

s3_key_from_version_id () {
    # Return the Key, filepath, of a named ${version_id} from ${s3_bucket_name}
    local s3_bucket_name=$1
    local version_id=$2
    aws s3api list-object-versions \
        --bucket ${s3_bucket_name} \
        --query "*[?VersionId=='${version_id}'].Key" \
        --output text
    return $?
}

s3_delete_object_versions () {
    # Iterate over all ${versions[@]} and delete all objects in one fell swoop
    local s3_bucket_name=$1
    shift
    local -a versions=(${@})

    aws s3api delete-objects \
        --bucket ${s3_bucket_name} \
        --delete "Objects=[
$(for index in $(seq 1 ${#versions[@]}); do
    # Bash array element counting starts from 1
    # The Bash array element index starts from 0
    # Yay for in-variable arithmetic..
    local version="${versions[$((${index} - 1))]}"
    if [[ ${index} -lt ${#versions[@]} ]]; then
        echo "            {Key=$(s3_key_from_version_id ${s3_bucket_name} ${version}),VersionId=${version}},"
    else
        # JSON fails with superfluous trailing commas
        echo "            {Key=$(s3_key_from_version_id ${s3_bucket_name} ${version}),VersionId=${version}}"
    fi
done)
        ],Quiet=false"
}

s3_purge_versions () {
    # Iterate over all versions of all objects inside ${s3_bucket_name} and
    # delete them. This must be tackled in the specific order of archived
    # versions, current verions and then delete markers.
    local s3_bucket_name=$1

    local -a not_latest_versions=($(s3_list_versions ${s3_bucket_name} foobarbaz))
    [[ ${not_latest_versions[@]-} ]] \
        && echoerr "WARNING: Deleting old versions" \
        && s3_delete_object_versions ${s3_bucket_name} ${not_latest_versions[@]} \
        || echoerr "INFO: No old object versions found."

    local -a latest_versions=($(s3_list_versions ${s3_bucket_name}))
    [[ ${latest_versions[@]-} ]] \
        && echoerr "WARNING: Deleting current versions" \
        && s3_delete_object_versions ${s3_bucket_name} ${latest_versions[@]} \
        || echoerr "INFO: No object versions found."

    local -a delete_markers=($(s3_list_delete_markers ${s3_bucket_name}))
    if [[ ${delete_markers[@]-} ]] && [[ ! ${delete_markers[0]} == "None" ]]; then
        echoerr "WARNING: Deleting delete markers"
        s3_delete_object_versions ${s3_bucket_name} ${delete_markers[@]}
    else
        echoerr "INFO: No Delete Markers."
    fi
}

s3_download () {
    # Download a named object from ${s3_bucket_name}
    local stack_name=$1
    local source=$2
    local destination=$3
    local options=${4-}

    # Remove / prefix, s3 does not like '//'
    local source=${source/#\//}

    if [[ ${source-} =~ /$ ]] || [[ -z ${source-} ]]; then
        local verb=sync
    else
        local verb=cp
    fi

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}"
    echoerr "INFO: Downloading resources from ${s3_url}/"
    aws s3 ${verb} ${options-} ${s3_url}/${source-} ${destination}
    return $?
}

s3_upload () {
    # Upload a named object to ${s3_bucket_name}
    local stack_name=$1
    local source=$2
    local destination=$3
    local options=${4-}

    # Remove / prefix, s3 does not like '//'
    destination=${destination/#\//}

    [[ ${source} =~ /$ ]] \
        && local verb=sync \
        || local verb=cp

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}"
    echoerr "INFO: Uploading resources to ${s3_url}/"
    aws s3 ${verb} ${options-} ${source} s3://${s3_bucket_name}/${destination-}
    return $?
}

