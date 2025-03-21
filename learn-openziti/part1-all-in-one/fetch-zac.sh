#!/usr/bin/env bash

# Parameters
repo="openziti/ziti-console"
version="$1"  # Pass version as the first argument, defaults later
apiUrl="https://api.github.com/repos/$repo/releases"
zacDir="/openziti/zac"

# Download artifact function
download_artifact() {
  local tag="$1"
  local artifactName="$2"
  local url="https://github.com/$repo/releases/download/$tag/$artifactName"
  local outputPath="$zacDir/$tag.zip"

  mkdir -p "$zacDir"
  >&2 echo "Downloading artifact from: $url"
  curl -sL "$url" -o "$outputPath"
  >&2 echo "Artifact saved to: $outputPath"
  echo "$outputPath"
}

# Unzip artifact function
unzip_artifact() {
  local zipPath="$1"
  local extractTo="$2"

  if [ ! -f "$zipPath" ]; then
    echo "Zip file not found: $zipPath"
    exit 1
  fi

  mkdir -p "$extractTo"
  echo "Extracting $zipPath to $extractTo"
  unzip -oq "$zipPath" -d "$extractTo"
  echo "Extraction complete."
}

# Fetch releases
releases_json=$(curl -sL -H "User-Agent: Bash" "$apiUrl") || {
  echo "Error fetching releases"
  exit 1
}

# If version not provided or "latest", find latest release
if [ -z "$version" ] || [ "$version" = "latest" ]; then
  latestRelease=$(echo "$releases_json" | jq -r '.[] | select(.tag_name | test("app-ziti-console-")) | .tag_name' | head -n1)
  
  if [ -n "$latestRelease" ]; then
    echo "Latest release found: $latestRelease"
    artifactPath=$(download_artifact "$latestRelease" "ziti-console.zip")
    where="$zacDir/$(echo "$latestRelease" | sed 's/^app-//')"
    unzip_artifact "$artifactPath" "$where"
    echo "      - binding: zac"
    echo "        options:"
    echo "          location: \"$where\""
    echo "          indexFile: index.html"
  else
    echo "No releases matching 'app-ziti-console-' found."
  fi
  exit 0
fi

# Validate version format
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version format. Use #.#.# (e.g., 3.7.0)."
  exit 1
fi

pattern="app-ziti-console-v$version"
matchingRelease=$(echo "$releases_json" | jq -r --arg pattern "$pattern" '.[] | select(.tag_name | test($pattern)) | .tag_name' | head -n1)

if [ -n "$matchingRelease" ]; then
  echo "Matching release foundb: $matchingRelease"
  artifactPath=$(download_artifact "$matchingRelease" "ziti-console.zip")
  where="$zacDir/$(echo "$matchingRelease" | sed 's/^app-//')"
  unzip_artifact "$artifactPath" "$where"
  echo "      - binding: zac"
  echo "        options:"
  echo "          location: \"$where\""
  echo "          indexFile: index.html"
else
  echo "No matching release found for pattern: $pattern"
fi
