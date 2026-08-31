readonly AGENT_SOURCE_IMAGE_REPOSITORY="709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free"
readonly DEFAULT_AGENT_IMAGE_TAG="20260828-095016-218a6dd4"
readonly DEFAULT_AGENT_IMAGE_URL="${AGENT_SOURCE_IMAGE_REPOSITORY}:${DEFAULT_AGENT_IMAGE_TAG}"

readonly EXPIRED_AGENT_IMAGE_URLS=(
  "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracis-free:20260520-125957-0fb7c715"
  "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free:20260826-113900-f19f9f21"
)


image_is_expired() {
  local image_url="$1"
  local expired_image_url

  for expired_image_url in "${EXPIRED_AGENT_IMAGE_URLS[@]}"; do
    if [ "${image_url}" = "${expired_image_url}" ]; then
      return 0
    fi
  done

  return 1
}

resolve_agent_image_url() {
  local agent_image_url="$1"

  agent_image_url="$(
    printf '%s' "${agent_image_url}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
  )"

  if [ -z "${agent_image_url}" ] || image_is_expired "${agent_image_url}"; then
    agent_image_url="${DEFAULT_AGENT_IMAGE_URL}"
  fi

  printf '%s\n' "${agent_image_url}"
}

prepare_agent_image() {
  local agent_image_url="$1"
  local mirror_repository_uri="$2"
  local aws_region="$3"
  local image_tag
  local mirrored_image_digest
  local source_image_registry
  local source_image_region

  agent_image_url="$(resolve_agent_image_url "$1")"

  if [[ "${agent_image_url}" == "${AGENT_SOURCE_IMAGE_REPOSITORY}:"* ]]; then
    image_tag="${agent_image_url##*:}"

    source_image_registry="${AGENT_SOURCE_IMAGE_REPOSITORY%%/*}"
    source_image_region="${source_image_registry#*.dkr.ecr.}"
    source_image_region="${source_image_region%%.amazonaws.com*}"

    mirrored_image_digest="$(
      aws ecr describe-images \
      --repository-name "${mirror_repository_uri#*/}" \
      --image-ids "imageTag=${image_tag}" \
      --query 'imageDetails[0].imageDigest' \
      --output text 2>/dev/null || true
    )"

    if [ -z "${mirrored_image_digest}" ] || [ "${mirrored_image_digest}" = "None" ]; then
      echo "Mirroring the agent image to the deployment Region..." >&2

      aws ecr get-login-password --region "${source_image_region}" \
        | docker login --username AWS --password-stdin "${source_image_registry}" >&2 \
        || return 1

      aws ecr get-login-password --region "${aws_region}" \
        | docker login --username AWS --password-stdin "${mirror_repository_uri%%/*}" >&2 \
        || return 1

      docker pull "${agent_image_url}" >&2 || return 1
      docker tag "${agent_image_url}" "${mirror_repository_uri}:${image_tag}" >&2 || return 1
      docker push "${mirror_repository_uri}:${image_tag}" >&2 || return 1

      if ! mirrored_image_digest="$(
        aws ecr describe-images \
        --repository-name "${mirror_repository_uri#*/}" \
        --image-ids "imageTag=${image_tag}" \
        --query 'imageDetails[0].imageDigest' \
        --output text
      )"; then
        return 1
      fi
    fi

    agent_image_url="${mirror_repository_uri}@${mirrored_image_digest}"
  fi

  printf '%s\n' "${agent_image_url}"
}
