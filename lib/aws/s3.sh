#!/usr/bin/env bash
#
# SIMPLE STORAGE SERVICE (S3) FUNCTIONS
#
s3_delete_objects () {
    local s3_bucket_name=$1
    local json=$2

    if ! $(echo ${json} | jq '.' &>/dev/null); then
        echoerr "ERROR: JSON is invalid"
        return 255
    fi

    # The JSON string can be so long that the maximum command length can be
    # exceeded. To get around this eventuality, write that shit to tmp, yo!
    # But, write out the file in a way that is human parseable.
    local tmp_file=$(mktemp)
    echo "{\"Objects\": ${json}, \"Quiet\": true}" \
        | jq '.' \
        | tee ${tmp_file} &>/dev/null

    # See `aws s3api delete-objects help` for limits.
    if [[ $(grep -c VersionId ${tmp_file}) -gt 999 ]]; then
        echoerr "ERROR: Too many objects to delete"
        return 1
    fi

    aws s3api delete-objects \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --delete "file://${tmp_file}"

    rm -f ${tmp_file}

    return $?
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
    aws s3 ${verb} --region ${AWS_REGION} ${options-} ${s3_url}/${source-} ${destination}
    return $?
}

s3_get_versions () {
    # Enumerate either latest, or archived versions of objects in a versioned
    # ${s3_bucket_name}. Returns VersionIds as an array
    local s3_bucket_name=$1
    local is_latest=$2

    if [[ ! ${is_latest} =~ ^(true|false)$ ]]; then
        echoerr "ERROR: is_latest can only be 'true' or 'false'"
        return 1
    fi

    # TODO: We can oly delete a maximum of 1000 objects at any one time.
    # we need a way to handle this more intelligently instead of relying
    # on the user to run this several times..
    aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --max-items 1000 \
        --query "[Versions][?IsLatest==${is_latest}][].{VersionId:VersionId,Key:Key}" \
        | jq -c '.'

    return $?
}

s3_get_delete_markers () {
    # When an object is deleted a DeleteMarker is set. Enumerate all
    # DeleteMarkers and return VersionIds as an array
    local s3_bucket_name=$1

    aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --query "DeleteMarkers[].{VersionId:VersionId,Key:Key}" \
        | jq -c '.'

    return $?
}

s3_get_file_version () {
    local stack_name=$1
    local file_path=$2
    local version_timestamp=$3
    local destination=$4

    [[ ${file_path} =~ ^\/ ]] \
        && file_path=${file_path/\//}

    [[ -d ${destination} ]] \
        && destination="${destination}/$(basename ${file_path})"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})

    local version_id=$(aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --prefix "${file_path}" \
        --query "Versions[?LastModified=='${version_timestamp}'].VersionId" \
        --output text)

    echoerr "INFO: Getting version '${version_id}' of '${file_path}'"
    aws s3api get-object \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key ${file_path} \
        --version-id ${version_id} \
        ${destination}

    return $?
}

s3_file_versions () {
    local stack_name=$1
    local file_path=$2

    [[ ${file_path} =~ ^\/ ]] \
        && file_path=${file_path/\//}

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})

    local version_timestamps=($(aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --prefix "${file_path}" \
        --query "Versions[].LastModified" \
        --output text))

    echo ${version_timestamps[@]}
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
    aws s3 ls --region ${AWS_REGION} ${s3_url}
    return $?
}

s3_purge_versions () {
    # Iterate over all versions of all objects inside ${s3_bucket_name} and
    # delete them. This must be tackled in the specific order of archived
    # versions, current verions and then delete markers.
    local s3_bucket_name=$1

    local not_latest_json=$(s3_get_versions ${s3_bucket_name} false)
    if [[ ${not_latest_json-} ]] && [[ ! ${not_latest_json-} =~ ^\[\]$ ]]; then
        echoerr "WARNING: Deleting old versions"
        s3_delete_objects ${s3_bucket_name} ${not_latest_json}
    else
        echoerr "INFO: No old objects found."
    fi

    local latest_json=$(s3_get_versions ${s3_bucket_name} true)
    if [[ ${latest_json-} ]] && [[ ! ${latest_json-} =~ ^\[\]$ ]]; then
        echoerr "WARNING: Deleting current versions"
        s3_delete_objects ${s3_bucket_name} ${latest_json}
    else
        echoerr "INFO: No current objects found."
    fi

    local delete_marker_json=$(s3_get_delete_markers ${s3_bucket_name})
    if [[ ${delete_marker_json-} ]] && [[ ! ${delete_marker_json-} =~ ^(null|None|\[\])$ ]]; then
        echoerr "WARNING: Deleting delete markers"
        s3_delete_objects ${s3_bucket_name} ${delete_marker_json}
    else
        echoerr "INFO: No Delete Markers."
    fi
}

s3_rm () {
    local stack_name=$1
    local file_path=$2
    shift 2
    local options=($*)

    local s3_bucket=$(s3_stack_bucket_name ${stack_name})

    [[ ${file_path} =~ ^/ ]] \
        && file_path=${file_path:1}

    aws s3 rm s3://${s3_bucket}/${file_path} ${options[@]-}
    return $?
}

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
    aws s3 ${verb} --region ${AWS_REGION} ${options-} ${source} s3://${s3_bucket_name}/${destination-}
    return $?
}

s3_upload_multipart () {
    # Upload a named object to ${s3_bucket_name} using the multipart upload API
    local stack_name=${1}
    local source=$(realpath ${2})
    local destination=${3}
    local options=${4-}

    # Maybe parameterise chunk size?
    local chunksize=5m

    # Remove / prefix, s3 does not like '//'
    destination=${destination/#\//}

    if [[ ${source} =~ /$ ]]; then
        echoerr "ERROR: Only individual files currently supported by s3_upload_multipart"
        return 1
    fi

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}"
    echoerr "INFO: Uploading resources to ${s3_url}/"

    # Store arrays of file names, with corresponding upload 'etags'
    local -a files
    local -a etags

    # Checksum and key for the file upload
    local csum="$(openssl md5 -binary ${source} | base64)"
    local key=$(basename "${source}")

    # Set up temporary directory and a cleanup command so we can exit cleanly and easily on errors
    local filesdir="$(mktemp --tmpdir -d s3upload.XXXXXX)"
    pushd ${filesdir} >/dev/null

        split -a 4 -b ${chunksize} ${source} s3part-

        # Dummy file entry in index 0, since s3 API indexes file parts starting from 1
        files=(dummy $(ls -1 s3part-* | sort))

        # Initiate the upload and retrieve the upload ID from the response
        local response=$(aws s3api create-multipart-upload \
            --region ${AWS_REGION} \
            --bucket ${s3_bucket_name} \
            --key ${key} \
            --metadata md5=${csum})
        local upload_id=$(echo "${response}" | jq -r '.UploadId')
        if [[ -z "${upload_id}" ]]; then
            echoerr "ERROR: Unable to initiate multipart upload"
            popd >/dev/null
            rm -rf ${filesdir}
            return 1
        fi

        # Iterate through the file parts, uploading each one
        local num_parts=$((${#files[@]} - 1))
        local index
        for index in $(seq ${num_parts}); do
            echoerr "INFO: uploading part ${index} of ${num_parts}..."
            local file=${files[$index]};
            local etag=$(_s3_upload_multipart_part ${s3_bucket_name} ${key} ${index} ${file} "${upload_id}")
            if [[ -z "${etag}" ]]; then
                echoerr "ERROR: Upload failed on part ${index} of ${num_parts}"
                popd >/dev/null
                rm -rf ${filesdir}
                return 1
            fi
            etags[${index}]="${etag}"
        done

        # Assemble that sucker together at the other end...
        local fileparts=${filesdir}/fileparts.json
        local comma=','
        printf '{"Parts": [\n' >> ${fileparts}
        for index in $(seq ${num_parts}); do
            [[ ${index} -eq ${num_parts} ]] && comma=""
            # the ETags come back pre-quoted, for some reason...
            printf '{"ETag": %s, "PartNumber": %d}%s\n' ${etags[${index}]} ${index} "${comma}" >> ${fileparts}
        done
        printf ']}\n' >> ${fileparts}

        # Make the final API call and check the result
        response=$(aws s3api complete-multipart-upload \
            --region ${AWS_REGION} \
            --multipart-upload "file://${fileparts}" \
            --bucket ${s3_bucket_name} \
            --key ${key} \
            --upload-id "${upload_id}")

        local location=$(echo "${response}" | jq -r '.Location')
        if [[ -z ${location} ]]; then
            echoerr "ERROR: Failed to complete multipart upload"
            popd >/dev/null
            rm -rf ${filesdir}
            return 1
        fi

        echoerr "INFO: File successfully uploaded to ${location}"

        popd >/dev/null

    rm -rf ${filesdir}

    return 0
}

_s3_upload_multipart_part() {
    local s3_bucket_name=${1}
    local key=${2}
    local part=${3}
    local file=${4}
    local upload_id=${5}
    local md5=$(openssl md5 -binary ${file} | base64)
    local response
    local etag

    local max_retries=10
    local retry
    for retry in $(seq ${max_retries}); do
        response=$(aws s3api upload-part \
            --region ${AWS_REGION} \
            --bucket ${s3_bucket_name} \
            --key ${key} \
            --part-number ${part} \
            --body ${file} \
            --upload-id ${upload_id} \
            --content-md5 ${md5})
        etag=$(echo $response | jq -r '.ETag')
        if [[ -z "$etag" ]]; then
            echoerr "INFO: Upload of part ${part} failed on attempt ${retry}"
	    if [[ ${retry} -lt ${max_retries} ]]; then
		echoerr "INFO: retrying..."
		 # Wait a few seconds in case of temporary connectivity loss
		sleep 3
	    fi
	    continue
        fi

        # Success, return the etag
        echo "${etag}"
        return 0
    done

    return 1
}
