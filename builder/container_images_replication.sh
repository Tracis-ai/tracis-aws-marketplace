readonly AGENT_SOURCE_IMAGE_REPOSITORY="709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free"
readonly MYSQL_TOOLS_SOURCE_IMAGE_REPOSITORY="709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-mysql-tools"

readonly DEFAULT_AGENT_IMAGE_TAG="20261019-133826-9cf87625"
readonly DEFAULT_MYSQL_TOOLS_IMAGE_TAG="20261019-133823-16b72948"

readonly DEFAULT_AGENT_IMAGE_URL="${AGENT_SOURCE_IMAGE_REPOSITORY}:${DEFAULT_AGENT_IMAGE_TAG}"
readonly DEFAULT_MYSQL_TOOLS_IMAGE_URL="${MYSQL_TOOLS_SOURCE_IMAGE_REPOSITORY}:${DEFAULT_MYSQL_TOOLS_IMAGE_TAG}"

readonly EXPIRED_AGENT_IMAGE_URLS=(
  "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracis-free:20260520-125957-0fb7c715"
  "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free:20260826-113900-f19f9f21"
  "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free:20260828-095016-218a6dd4"
)
readonly EXPIRED_MYSQL_TOOLS_IMAGE_URLS=()

resolve_image_url() {
  local image_type="$1"
  local image_url="$2"
  local default_image_url
  local expired_image_urls
  local expired_image_url

  case "${image_type}" in
    agent)
      default_image_url="${DEFAULT_AGENT_IMAGE_URL}"
      expired_image_urls=("${EXPIRED_AGENT_IMAGE_URLS[@]}")
      ;;
    mysql_tools)
      default_image_url="${DEFAULT_MYSQL_TOOLS_IMAGE_URL}"
      expired_image_urls=("${EXPIRED_MYSQL_TOOLS_IMAGE_URLS[@]:-}")
      ;;
    *)
      echo "Unsupported image type: ${image_type}" >&2
      return 1
      ;;
  esac

  image_url="$(printf '%s' "${image_url}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  for expired_image_url in "${expired_image_urls[@]:-}"; do
    if [ "${image_url}" = "${expired_image_url}" ]; then
      image_url=""
      break
    fi
  done

  if [ -z "${image_url}" ]; then
    if [ "${image_type}" = "mysql_tools" ] && [ -z "${DEFAULT_MYSQL_TOOLS_IMAGE_TAG}" ]; then
      echo "The standard MySQL image has not been published. Specify MySqlToolsImageUrl." >&2
      return 1
    fi
    image_url="${default_image_url}"
  fi

  printf '%s\n' "${image_url}"
}

prepare_image() {
  local image_type="$1"
  local image_url="$2"
  local mirror_repository_uri="$3"
  local aws_region="$4"
  local source_repository
  local image_tag
  local mirrored_image_digest
  local source_image_registry
  local source_image_region

  image_url="$(resolve_image_url "${image_type}" "${image_url}")" || return 1

  case "${image_type}" in
    agent)
      source_repository="${AGENT_SOURCE_IMAGE_REPOSITORY}"
      ;;
    mysql_tools)
      source_repository="${MYSQL_TOOLS_SOURCE_IMAGE_REPOSITORY}"
      ;;
  esac

  if [[ "${image_url}" == "${source_repository}:"* ]]; then
    if [ -z "${mirror_repository_uri}" ]; then
      echo "The mirror repository URI is required for a standard image." >&2
      return 1
    fi
    image_tag="${image_url##*:}"

    source_image_registry="${source_repository%%/*}"
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
      echo "Mirroring the container images to the deployment Region..." >&2

      aws ecr get-login-password --region "${source_image_region}" \
        | docker login --username AWS --password-stdin "${source_image_registry}" >&2 \
        || return 1

      aws ecr get-login-password --region "${aws_region}" \
        | docker login --username AWS --password-stdin "${mirror_repository_uri%%/*}" >&2 \
        || return 1

      docker pull "${image_url}" >&2 || return 1
      docker tag "${image_url}" "${mirror_repository_uri}:${image_tag}" >&2 || return 1
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

    image_url="${mirror_repository_uri}@${mirrored_image_digest}"
  fi

  printf '%s\n' "${image_url}"
}
