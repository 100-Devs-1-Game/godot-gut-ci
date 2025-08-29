#!/bin/bash
set -e
set -o pipefail

GODOT_VERSION=$1
GUT_PARAMS=$2
PROJECT_PATH=$3
GODOT_BIN=/usr/local/bin/godot

# Download Godot
GODOT_PARAMS=
is_version_4=$( [[ $GODOT_VERSION == 4* ]] && echo "true" || echo "false" )
TEMP_FILE_INIT=/tmp/godot_init.log
TEMP_FILE_IMPORT=/tmp/godot_import.log
TEMP_FILE_TESTS=/tmp/godot_tests.log

echo ""
echo "#####################"
echo "     DOWNLOADING     "
echo "#####################"

if [[ $is_version_4 == "true" ]]; then
  echo "Godot4"
  echo ""

  wget --progress=dot:mega https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip

  # Unzip it
  unzip Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
  mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 $GODOT_BIN
  GODOT_PARAMS="--headless"
else
  echo "Godot3"
  echo ""

  # Use official release download
  wget --progress=dot:mega https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux_headless.64.zip

  # Unzip it
  unzip Godot_v${GODOT_VERSION}-stable_linux_headless.64.zip
  mv Godot_v${GODOT_VERSION}-stable_linux_headless.64 $GODOT_BIN
fi

# Run the tests
if [[ -n $PROJECT_PATH ]]; then
  cd $PROJECT_PATH
fi

echo ""
echo ""
echo ""
echo ""
echo ""
echo "#####################"
echo "    INITIALIZING     "
echo "#####################"

echo Load godot once to initialize 
$GODOT_BIN --headless --editor --render-thread safe --single-threaded-scene --quit --verbose 2>&1 | tee $TEMP_FILE_INIT

echo ""
echo ""
echo ""
echo ""
echo ""
echo "#####################"
echo "     IMPORTING       "
echo "#####################"

echo Importing resources
$GODOT_BIN --import --headless --render-thread safe --single-threaded-scene --quit --verbose 2>&1 | tee $TEMP_FILE_IMPORT

echo ""
echo ""
echo ""
echo ""
echo ""
echo "#####################"
echo "      TESTING        "
echo "#####################"

echo Running GUT tests using params:
echo "  -> $GUT_PARAMS"
echo ""

$GODOT_BIN -d -s $GODOT_PARAMS --path $PWD addons/gut/gut_cmdln.gd -gexit $GUT_PARAMS --render-thread safe --single-threaded-scene --verbose 2>&1 | tee $TEMP_FILE_TESTS




# !!!!!
# MAKE SURE THIS SECTION STAYS IN SYNC WITH THE CICD IN THE MAIN REPO
# !!!!



echo ""
echo ""
echo ""
echo ""
echo ""
echo "#####################"
echo "       RESULTS       "
echo "#####################"
echo ""

FAILED=0

# Check for any error lines (case-insensitive)
# Ignores null time for textures: https://github.com/godotengine/godot/issues/108994
FILTERED_ERRORS_INIT=$(grep "ERROR" "$TEMP_FILE_INIT" | grep -v 'ERROR: Parameter "t" is null.') || true
FILTERED_ERRORS_IMPORT=$(grep "ERROR" "$TEMP_FILE_IMPORT" | grep -v 'ERROR: Parameter "t" is null.') || true
FILTERED_ERRORS_TESTS=$(grep "ERROR" "$TEMP_FILE_TESTS" | grep -v 'ERROR: Parameter "t" is null.') || true

# Check for invalid UID warnings which will cause problems for other people
FILTERED_WARNINGS_INIT=$(grep "WARNING" "$TEMP_FILE_INIT" | grep 'invalid UID:') || true
FILTERED_WARNINGS_IMPORT=$(grep "WARNING" "$TEMP_FILE_IMPORT" | grep 'invalid UID:') || true
FILTERED_WARNINGS_TESTS=$(grep "WARNING" "$TEMP_FILE_TESTS" | grep 'invalid UID:') || true

# INIT

if [ -n "$FILTERED_ERRORS_INIT" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT ERRORS ON INITIALIZING:"
  echo "$FILTERED_ERRORS_INIT"
  echo ""
  FAILED=1
fi

if [ -n "$FILTERED_WARNINGS_INIT" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT WARNINGS ON INITIALIZING:"
  echo "$FILTERED_WARNINGS_INIT"
  echo ""
  FAILED=1
fi

# IMPORT

if [ -n "$FILTERED_ERRORS_IMPORT" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT ERRORS ON IMPORTING:"
  echo "$FILTERED_ERRORS_IMPORT"
  echo ""
  FAILED=1
fi

if [ -n "$FILTERED_WARNINGS_IMPORT" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT WARNINGS ON IMPORTING:"
  echo "$FILTERED_WARNINGS_IMPORT"
  echo ""
  FAILED=1
fi

# TESTS

if [ -n "$FILTERED_ERRORS_TESTS" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT ERRORS ON TESTING:"
  echo "$FILTERED_ERRORS_TESTS"
  echo ""
  FAILED=1
fi

if [ -n "$FILTERED_WARNINGS_TESTS" ]; then
  echo "CI FAILED BECAUSE OF THESE GODOT WARNINGS ON TESTING:"
  echo "$FILTERED_WARNINGS_TESTS"
  echo ""
  FAILED=1
fi

# Godot always exists with error 0, but we want this action to fail in case of errors
if grep -q "No tests ran" "$TEMP_FILE_TESTS" || grep -qE "Asserts\s+none" "$TEMP_FILE_TESTS";
then
  echo "CI FAILED BECAUSE NO TESTS RAN"
  echo ""
  FAILED=1
fi

if  ! grep -q "All tests passed" "$TEMP_FILE_TESTS"
then
  echo "CI FAILED BECAUSE SOME TESTS FAILED"
  echo ""
  FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then
  echo "ALL GOOD :) :) :)"
fi

echo ""
echo ""
echo ""
echo ""
echo ""

exit $FAILED
