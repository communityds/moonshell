#!/usr/bin/env bash
#
# SIMPLE STORAGE SERVICE (S3) FUNCTIONS
#
s3_cp () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME SOURCE DESTINATION"
        return 1
    fi
    local stack_name="$1"
    local src="$(s3_path_sanitise ${2})"
    local dst="$(s3_path_sanitise ${3})"
    shift 3
    local options="$*"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local kms_key_id="$(kms_stack_key_id ${stack_name})"
    [[ ${kms_key_id-} ]] \
        && options="${options-} --sse=aws:kms --sse-kms-key-id ${kms_key_id}"

    echoerr "INFO: Copying '${src}' to '${dst}'"
    aws s3 cp \
        --region ${AWS_REGION} \
        "s3://${s3_bucket_name}/${src}" \
        "s3://${s3_bucket_name}/${dst}" \
        ${options-}
    return $?
}

s3_delete_objects () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET JSON"
        return 1
    fi
    # Sample JSON input:
    # [{
    #   "VersionId":"nkfayP3f3lLFmrBanFSNl4pc8ytT8ZY4",
    #   "Key":"dummy-location/file.name"
    # }]
    local s3_bucket_name="$1"
    local json="$2"

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
    if [[ $(grep -c VersionId ${tmp_file}) -gt 1000 ]]; then
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
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    # Download a named object from ${s3_bucket_name}
    local stack_name="$1"
    local source="$(s3_path_sanitise ${2})" # Remote
    local destination="$3" # Local
    shift 3
    local options="$*"

    # Remove / prefix, s3 does not like '//'
    local source=${source/#\//}

    if [[ -z ${source-} ]] || [[ ${source} =~ /$ ]]; then
        local verb=sync
    else
        local verb=cp
    fi

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}"

    local kms_key_id="$(kms_stack_key_id ${stack_name})"
    [[ ${kms_key_id-} ]] \
        && options="${options-} --sse=aws:kms --sse-kms-key-id ${kms_key_id}"

    echoerr "INFO: Downloading resources from ${s3_url}/"
    aws s3 ${verb} --region ${AWS_REGION} ${options-} "${s3_url}/${source-}" "${destination}"
    return $?
}

s3_file_versions () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH"
        return 1
    fi
    local stack_name="$1"
    local file_path="$2"

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

s3_get_delete_markers () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET PREFIX"
        return 1
    fi
    # When an object is deleted a DeleteMarker is set. Enumerate all
    # DeleteMarkers and return VersionIds as an array
    local s3_bucket_name="$1"
    local s3_prefix="${2-}"

    echoerr "INFO: Gathering 1000 objects"
    # --max-items appears to be broken, but we should try to reduce load on
    # the AWS API anyway.
    aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --prefix "${s3_prefix-}" \
        --max-items 1000 \
        --query "DeleteMarkers[].{VersionId:VersionId,Key:Key}" \
        | jq -c '[limit (1000; .[] | select(.VersionId))]' 2>/dev/null

    return ${PIPESTATUS[0]}
}

s3_get_file_version () {
    if [[ $# -lt 4 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH VERSION_TIMESTAMP DESTINATION"
        return 1
    fi
    local stack_name="$1"
    local file_path="$2"
    local version_timestamp="$3"
    local destination="$4"

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

s3_get_versions () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET IS_LATEST [PREFIX]"
        return 1
    fi
    # Enumerate either latest, or archived versions of objects in a versioned
    # ${s3_bucket_name}. Returns VersionIds as an array
    local s3_bucket_name="$1"
    local is_latest="$2"
    local prefix="${3-}"

    if [[ ! ${is_latest} =~ ^(true|false)$ ]]; then
        echoerr "ERROR: is_latest can only be 'true' or 'false'"
        return 1
    fi

    # TODO: We can oly delete a maximum of 1000 objects at any one time.
    # we need a way to handle this more intelligently instead of relying
    # on the user to run this several times..
    echoerr "INFO: Gathering 1000 objects"
    # --max-items appears to be broken, but we should try to reduce load on
    # the AWS API anyway.
    aws s3api list-object-versions \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --prefix "${prefix}" \
        --max-items 1000 \
        --query "[Versions][?IsLatest==${is_latest}][].{VersionId:VersionId,Key:Key}" \
        | jq -c '[limit (1000; .[] | select(.VersionId))]' 2>/dev/null

    return ${PIPESTATUS[0]}
}

s3_ls () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME PREFIX"
        return 1
    fi
    local stack_name="$1"
    local location="$(s3_path_sanitise ${2-} 2>/dev/null)"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local s3_url="s3://${s3_bucket_name}/${location-}"
    echoerr "INFO: Listing objects in ${s3_url}"
    aws s3 ls --region ${AWS_REGION} ${s3_url}
    return $?
}

s3_mv () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    local stack_name="$1"
    local src="$(s3_path_sanitise ${2})"
    local dst="$(s3_path_sanitise ${3})"
    shift 3
    local options="$*"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local kms_key_id="$(kms_stack_key_id ${stack_name})"
    [[ ${kms_key_id-} ]] \
        && options="${options-} --sse=aws:kms --sse-kms-key-id ${kms_key_id}"

    echoerr "INFO: Moving '${src-}' to '${dst-}'"
    aws s3 mv \
        --region ${AWS_REGION} \
        "s3://${s3_bucket_name}/${src-}" \
        "s3://${s3_bucket_name}/${dst-}" \
        ${options-}
    return $?
}

s3_path_sanitise () {
    if [[ $# -lt 1 ]] ;then
        "Usage: ${FUNCNAME[0]} PREFIX"
        return 1
    fi
    # We must strip ^/ from all s3 paths
    local s3_path="$*"

    echo "${s3_path-}" \
        | sed -e 's/^\/*//'
}

s3_purge_versions () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET PREFIX"
        return 1
    fi
    # Iterate over all versions of all objects inside ${s3_bucket_name} and
    # delete them. This must be tackled in the specific order of archived
    # versions, current verions and then delete markers.
    local s3_bucket_name="$1"
    local s3_prefix="${2-}"

    local delete_marker_json latest_json not_latest_json

    not_latest_json="$(s3_get_versions ${s3_bucket_name} false "${s3_prefix-}")"
    while [[ ${not_latest_json-} ]] && [[ ! ${not_latest_json-} =~ ^\[\]$ ]]; do
        echoerr "WARNING: Deleting old versions"
        s3_delete_objects ${s3_bucket_name} "${not_latest_json}"

        not_latest_json="$(s3_get_versions ${s3_bucket_name} false "${s3_prefix-}")"
    done

    latest_json="$(s3_get_versions ${s3_bucket_name} true "${s3_prefix-}")"
    while [[ ${latest_json-} ]] && [[ ! ${latest_json-} =~ ^\[\]$ ]]; do
        echoerr "WARNING: Deleting current versions"
        s3_delete_objects ${s3_bucket_name} "${latest_json}"
        latest_json="$(s3_get_versions ${s3_bucket_name} true "${s3_prefix-}")"
    done

    delete_marker_json="$(s3_get_delete_markers ${s3_bucket_name} "${s3_prefix-}")"
    while [[ ${delete_marker_json-} ]] && [[ ! ${delete_marker_json-} =~ ^(null|None|\[\])$ ]]; do
        echoerr "WARNING: Deleting delete markers"
        s3_delete_objects ${s3_bucket_name} "${delete_marker_json}"
        delete_marker_json="$(s3_get_delete_markers ${s3_bucket_name} "${s3_prefix-}")"
    done
}

s3_rm () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH [OPTIONS]"
        return 1
    fi
    local stack_name="$1"
    local file_path="$(s3_path_sanitise ${2})"
    shift 2
    local options="$*"

    local s3_bucket=$(s3_stack_bucket_name ${stack_name})

    aws s3 rm "s3://${s3_bucket}/${file_path-}" ${options-}
    return $?
}

s3_stack_bucket_name () {
    if [[ $# -lt 1 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME"
        return 1
    fi
    local stack_name="$1"

    if [[ ${S3_BUCKET-} ]]; then
        echo ${S3_BUCKET}
        return 0
    fi

    local -a s3_buckets=($(stack_resource_type_id ${stack_name} "AWS::S3::Bucket"))

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

s3_tag_delete () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH [VERSION_ID]"
        return 1
    fi
    local stack_name="$1"
    local s3_file="$2"
    local version_id="${3-}"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    echoerr "WARNING: This will permanently delete all tags for object '${s3_file}'"
    if prompt_no "Are you sure you wish to continue?"; then
        echoerr "INFO: Exiting on user request"
        return 0
    fi

    aws s3api delete-object-tagging \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key "${s3_file}" \
        $([[ ${version_id-} ]] && echo "--version-id ${version_id}") \
        >/dev/null
}

s3_tag_get () {
    if [[ $# -lt 2 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH"
        return 1
    fi
    local stack_name="$1"
    local s3_file="$2"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    aws s3api get-object-tagging \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key "${s3_file}" \
        --output table
}

s3_tag_set () {
    if [[ $# -lt 4 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME FILE_PATH KEY VALUE [VERSION_ID]"
        return 1
    fi
    local stack_name="$1"
    local s3_file="$2"
    local key="$3"
    local value="$4"
    local version_id="${5-}"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local current_tag_json tag_json

    current_tag_json=$(aws s3api get-object-tagging \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key "${s3_file}" \
        --query "TagSet")

    # TODO Add logic to handle the updating of tags
    if [[ -z ${current_tag_json-} ]] || [[ ${current_tag_json-} == "[]" ]]; then
        tag_json="[{\"Key\":\"${key}\",\"Value\":\"${value}\"}]"
    else
        tag_json="[{\"Key\":\"${key}\",\"Value\":\"${value}\"},$(echo ${current_tag_json} | jq -c '.[]' | paste -sd,)]"
    fi

    aws s3api put-object-tagging \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key "${s3_file}" \
        $([[ ${version_id-} ]] && echo "--version-id ${version_id}") \
        --tagging "{\"TagSet\":${tag_json}}" \
        >/dev/null
}

s3_upload () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} STACK_NAME SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    # Upload a named object to ${s3_bucket_name}
    local stack_name="$1"
    local source="$2" # Local
    local destination="$(s3_path_sanitise ${3})" # Remote
    shift 3
    local options="$*"

    local s3_bucket_name=$(s3_stack_bucket_name ${stack_name})
    [[ -z ${s3_bucket_name-} ]] && return 1

    local kms_key_id="$(kms_stack_key_id ${stack_name})"

    if [[ ${source} =~ /$ ]]; then
        [[ ${kms_key_id-} ]] \
            && options="${options-} --sse aws:kms --sse-kms-key-id ${kms_key_id}"

        s3_upload_path ${s3_bucket_name} "${source}" "${destination}" ${options-}
    else
        [[ ${kms_key_id-} ]] \
            && options="${options-} --server-side-encryption aws:kms --ssekms-key-id ${kms_key_id}"

        s3_upload_file ${s3_bucket_name} "${source}" "${destination}" ${options-}
    fi

}

s3_upload_file () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    local s3_bucket_name="$1"
    local source="$2"
    local destination="$(s3_path_sanitise ${3})"
    shift 3
    local options="$*"

    # If uploading a sufficiently large file, explicitly use the AWS multipart upload API
    case $(uname) in
        Darwin) local format_bytes="-f %z" ;;
        Linux) local format_bytes="-c %s" ;;
    esac

    # If ${destination} has a trailing slash we have to append the source
    # file else the file is created as the containing directory..
    # Yes, AWS lets you create a file called "foo/", even if a dir called
    # "foo/" already exists.. :thumbsup:
    if [[ -z ${destination-} ]] || [[ ${destination} =~ /$ ]]; then
        destination="${destination-}$(basename ${source})"
    fi

    aws s3api put-object \
        --region ${AWS_REGION} \
        --bucket ${s3_bucket_name} \
        --key "${destination}" \
        --body "${source}" \
        ${options-}
}

s3_upload_path () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    local s3_bucket_name="$1"
    local source="$2"
    local destination="$(s3_path_sanitise ${3})"
    shift 3
    local options="$*"

    [[ ! ${source} =~ /$ ]] && local source="${source}/"

    local s3_url="s3://${s3_bucket_name}/${destination-}"

    echoerr "INFO: Uploading resources to '${s3_url}'"
    aws s3 sync --region ${AWS_REGION} ${options-} "${source}" "${s3_url}"
}

s3_upload_multipart () {
    if [[ $# -lt 3 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET SOURCE DESTINATION [OPTIONS]"
        return 1
    fi
    # Upload a named object to ${s3_bucket_name} using the multipart upload API
    local s3_bucket_name="$1"
    local source="$(realpath ${2})"
    local destination="$(s3_path_sanitise ${3})"
    shift 3
    local options="$*"

    # Maybe parameterise chunk size?
    local chunksize=5m

    # Store arrays of file names, with corresponding upload 'etags'
    local -a files
    local -a etags

    # Checksum for the file upload
    local csum="$(openssl md5 -binary ${source} | base64)"

    # Set up temporary directory
    local filesdir="$(mktemp -d -t s3upload.XXXXXX)"
    pushd ${filesdir} >/dev/null

        split -a 4 -b ${chunksize} ${source} s3part-

        # Dummy file entry in index 0, since s3 API indexes file parts starting from 1
        files=(dummy $(ls -1 s3part-* | sort))

        # Initiate the upload and retrieve the upload ID from the response
        local response=$(aws s3api create-multipart-upload \
            --region ${AWS_REGION} \
            --bucket ${s3_bucket_name} \
            --key "${destination-}" \
            --metadata md5=${csum} \
            ${options-})
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
            local etag=$(_s3_upload_multipart_part ${s3_bucket_name} "${destination}" "${index}" "${file}" "${upload_id}")
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
            --key "${destination-}" \
            --upload-id "${upload_id}")

        local location=$(echo "${response}" | jq -r '.Location')
        if [[ -z ${location} ]]; then
            echoerr "ERROR: Failed to complete multipart upload"
            popd >/dev/null
            rm -rf ${filesdir}
            return 1
        fi

        echoerr "INFO: File successfully uploaded to '${location}'"

        popd >/dev/null

    rm -rf "${filesdir}"

    return 0
}

_s3_upload_multipart_part() {
    if [[ $# -lt 5 ]] ;then
        "Usage: ${FUNCNAME[0]} S3_BUCKET KEY PART FILE UPLOAD_ID"
        return 1
    fi
    local s3_bucket_name="$1"
    local key="$2"
    local part="$3"
    local file="$4"
    local upload_id="$5"

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
            --body "${file}" \
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
        elif [[ ${retry} -gt 1 ]]; then
            # Give feedback if the retry succeeded
            echoerr "INFO: Upload of part ${part} succeeded on attempt ${retry}"
        fi

        # Success, return the etag
        echo "${etag}"
        return 0
    done

    return 1
}
