#!/usr/bin/env bash
set -euo pipefail

BASE_REF=""
HEAD_REF="HEAD"
SOURCE_DIR="force-app/main/default"
OUTPUT_DIR="${RUNNER_TEMP:-/tmp}/sf-delta"

usage() {
  echo "Usage: $0 --base-ref <base-ref> [--head-ref HEAD] [--source-dir force-app/main/default] [--output-dir /tmp/sf-delta]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      BASE_REF="$2"
      shift 2
      ;;
    --head-ref)
      HEAD_REF="$2"
      shift 2
      ;;
    --source-dir)
      SOURCE_DIR="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$BASE_REF" ]]; then
  echo "Base ref must be specified." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

if git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_SHA="$(git rev-parse "$BASE_REF")"
else
  git fetch --no-tags --prune origin "${BASE_REF#origin/}" >/dev/null 2>&1 || true
  BASE_SHA="$(git rev-parse "origin/${BASE_REF#origin/}" 2>/dev/null || git rev-list --max-count=1 HEAD)"
fi

if [[ -z "$BASE_SHA" ]]; then
  echo "Unable to determine base SHA for diff generation." >&2
  exit 1
fi

git diff --name-status "${BASE_SHA}"..."${HEAD_REF}" -- "$SOURCE_DIR" > "$OUTPUT_DIR/changes.txt" || true

if [[ ! -s "$OUTPUT_DIR/changes.txt" ]]; then
  cat > "$OUTPUT_DIR/package.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <version>66.0</version>
</Package>
EOF
  : > "$OUTPUT_DIR/destructiveChanges.xml"
  echo "No source changes detected for delta deploy." >&2
  exit 0
fi

declare -A type_members=()
declare -A deleted_type_members=()

action_for() {
  local file="$1"
  local status="$2"

  case "$file" in
    "$SOURCE_DIR"/*)
      :
      ;;
    *)
      return 0
      ;;
  esac

  local relative_path="${file#${SOURCE_DIR}/}"
  if [[ -z "$relative_path" ]]; then
    return 0
  fi

  local member=""
  case "$relative_path" in
    lwc/*)
      local bundle="${relative_path#lwc/}"
      bundle="${bundle%%/*}"
      if [[ -n "$bundle" ]]; then
        member="$bundle"
        if [[ "$status" == "D" ]]; then
          deleted_type_members["LightningComponentBundle"]+="${deleted_type_members["LightningComponentBundle"]:+$'\n'}${member}"
        else
          type_members["LightningComponentBundle"]+="${type_members["LightningComponentBundle"]:+$'\n'}${member}"
        fi
      fi
      ;;
    aura/*)
      local bundle="${relative_path#aura/}"
      bundle="${bundle%%/*}"
      if [[ -n "$bundle" ]]; then
        member="$bundle"
        if [[ "$status" == "D" ]]; then
          deleted_type_members["AuraDefinitionBundle"]+="${deleted_type_members["AuraDefinitionBundle"]:+$'\n'}${member}"
        else
          type_members["AuraDefinitionBundle"]+="${type_members["AuraDefinitionBundle"]:+$'\n'}${member}"
        fi
      fi
      ;;
    classes/*)
      member="$(basename "$relative_path")"
      member="${member%.cls}"
      member="${member%.cls-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["ApexClass"]+="${deleted_type_members["ApexClass"]:+$'\n'}${member}"
        else
          type_members["ApexClass"]+="${type_members["ApexClass"]:+$'\n'}${member}"
        fi
      fi
      ;;
    triggers/*)
      member="$(basename "$relative_path")"
      member="${member%.trigger}"
      member="${member%.trigger-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["ApexTrigger"]+="${deleted_type_members["ApexTrigger"]:+$'\n'}${member}"
        else
          type_members["ApexTrigger"]+="${type_members["ApexTrigger"]:+$'\n'}${member}"
        fi
      fi
      ;;
    pages/*)
      member="$(basename "$relative_path")"
      member="${member%.page}"
      member="${member%.page-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["ApexPage"]+="${deleted_type_members["ApexPage"]:+$'\n'}${member}"
        else
          type_members["ApexPage"]+="${type_members["ApexPage"]:+$'\n'}${member}"
        fi
      fi
      ;;
    components/*)
      member="$(basename "$relative_path")"
      member="${member%.component}"
      member="${member%.component-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["ApexComponent"]+="${deleted_type_members["ApexComponent"]:+$'\n'}${member}"
        else
          type_members["ApexComponent"]+="${type_members["ApexComponent"]:+$'\n'}${member}"
        fi
      fi
      ;;
    labels/*)
      member="$(basename "$relative_path")"
      member="${member%.labels}"
      member="${member%.labels-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["CustomLabels"]+="${deleted_type_members["CustomLabels"]:+$'\n'}${member}"
        else
          type_members["CustomLabels"]+="${type_members["CustomLabels"]:+$'\n'}${member}"
        fi
      fi
      ;;
    flows/*)
      member="$(basename "$relative_path")"
      member="${member%.flow}"
      member="${member%.flow-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["Flow"]+="${deleted_type_members["Flow"]:+$'\n'}${member}"
        else
          type_members["Flow"]+="${type_members["Flow"]:+$'\n'}${member}"
        fi
      fi
      ;;
    profiles/*)
      member="$(basename "$relative_path")"
      member="${member%.profile}"
      member="${member%.profile-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["Profile"]+="${deleted_type_members["Profile"]:+$'\n'}${member}"
        else
          type_members["Profile"]+="${type_members["Profile"]:+$'\n'}${member}"
        fi
      fi
      ;;
    permissionsets/*)
      member="$(basename "$relative_path")"
      member="${member%.permissionset}"
      member="${member%.permissionset-meta.xml}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["PermissionSet"]+="${deleted_type_members["PermissionSet"]:+$'\n'}${member}"
        else
          type_members["PermissionSet"]+="${type_members["PermissionSet"]:+$'\n'}${member}"
        fi
      fi
      ;;
    staticresources/*)
      member="${relative_path#staticresources/}"
      member="${member%%/*}"
      if [[ -n "$member" ]]; then
        if [[ "$status" == "D" ]]; then
          deleted_type_members["StaticResource"]+="${deleted_type_members["StaticResource"]:+$'\n'}${member}"
        else
          type_members["StaticResource"]+="${type_members["StaticResource"]:+$'\n'}${member}"
        fi
      fi
      ;;
    *)
      member="$(basename "$relative_path")"
      member="${member%.*}"
      case "$relative_path" in
        *.xml)
          if [[ "$relative_path" == *.app-meta.xml ]]; then
            member="${member%.app-meta}"
            if [[ "$status" == "D" ]]; then
              deleted_type_members["CustomApplication"]+="${deleted_type_members["CustomApplication"]:+$'\n'}${member}"
            else
              type_members["CustomApplication"]+="${type_members["CustomApplication"]:+$'\n'}${member}"
            fi
          fi
          ;;
      esac
      ;;
  esac
}

while IFS=$'\t' read -r status file; do
  file="${file#./}"
  action_for "$file" "$status"
done < "$OUTPUT_DIR/changes.txt"

write_manifest() {
  local manifest_type="$1"
  local output_file="$2"
  local -n type_map="$3"

  {
    echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    echo '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'
    for type in "${!type_map[@]}"; do
      local members="${type_map[$type]}"
      if [[ -n "$members" ]]; then
        echo '    <types>'
        while IFS= read -r member; do
          [[ -n "$member" ]] || continue
          echo "        <members>${member}</members>"
        done <<< "$members"
        echo "        <name>${type}</name>"
        echo '    </types>'
      fi
    done
    echo '    <version>66.0</version>'
    echo '</Package>'
  } > "$output_file"
}

write_manifest "package" "$OUTPUT_DIR/package.xml" type_members
write_manifest "destructive" "$OUTPUT_DIR/destructiveChanges.xml" deleted_type_members

if [[ ! -s "$OUTPUT_DIR/package.xml" ]]; then
  echo "No package members were identified; creating empty package manifest." >&2
  cat > "$OUTPUT_DIR/package.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <version>66.0</version>
</Package>
EOF
fi

if [[ ! -s "$OUTPUT_DIR/destructiveChanges.xml" ]]; then
  : > "$OUTPUT_DIR/destructiveChanges.xml"
fi

echo "Delta manifest generated at $OUTPUT_DIR"
