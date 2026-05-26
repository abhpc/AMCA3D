#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-build}"
BUILD_TYPE="${BUILD_TYPE:-Release}"
CLEAN="${CLEAN:-1}"
JOBS="${JOBS:-}"
MPI_MODULE="${MPI_MODULE:-mpich/3.2}"
LOAD_MPI_MODULE="${LOAD_MPI_MODULE:-auto}"
PURGE_MODULES="${PURGE_MODULES:-1}"

die() {
    echo "error: $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

if [[ -z "${BUILD_DIR}" || "${BUILD_DIR}" = "." || "${BUILD_DIR}" = ".." || "${BUILD_DIR}" = /* ]]; then
    die "BUILD_DIR must be a non-empty relative path"
fi

if [[ "${LOAD_MPI_MODULE}" != "0" ]] && command -v module >/dev/null 2>&1; then
    if [[ "${PURGE_MODULES}" = "1" ]]; then
        echo "Purging loaded modules"
        module purge
    fi
    echo "Loading MPI module: ${MPI_MODULE}"
    if ! module load "${MPI_MODULE}"; then
        if [[ "${LOAD_MPI_MODULE}" = "1" ]]; then
            die "failed to load MPI module ${MPI_MODULE}"
        fi
        echo "warning: failed to load ${MPI_MODULE}; continuing with current environment" >&2
    fi
fi

require_command cmake
require_command make
require_command mpicc
require_command mpicxx

if command -v pkg-config >/dev/null 2>&1; then
    if pkg-config --exists yaml-cpp; then
        echo "Found yaml-cpp $(pkg-config --modversion yaml-cpp)"
    else
        echo "warning: pkg-config cannot find yaml-cpp; CMake/linker will perform the final check" >&2
    fi
fi

if [[ -z "${JOBS}" ]]; then
    if command -v nproc >/dev/null 2>&1; then
        JOBS="$(nproc)"
    else
        JOBS=4
    fi
fi

[[ "${JOBS}" =~ ^[0-9]+$ ]] || die "JOBS must be a positive integer"
[[ "${JOBS}" -gt 0 ]] || die "JOBS must be greater than 0"

BUILD_PATH="${SCRIPT_DIR}/${BUILD_DIR}"
CMAKE_OPTIONS=(
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
    -DCMAKE_C_COMPILER=mpicc
    -DCMAKE_CXX_COMPILER=mpicxx
)

if [[ -n "${BOOST_ROOT:-}" ]]; then
    CMAKE_OPTIONS+=(
        "-DBOOST_ROOT=${BOOST_ROOT}"
        "-DBOOST_INCLUDEDIR=${BOOST_ROOT}/include"
        "-DBOOST_LIBRARYDIR=${BOOST_ROOT}/lib"
        "-DBOOST_LIBRARY_DIR=${BOOST_ROOT}/lib"
    )
fi

if [[ -n "${YAML_ROOT:-}" ]]; then
    CMAKE_OPTIONS+=(
        "-DYAML_INCLUDE_DIR=${YAML_ROOT}/include"
        "-DYAML_LIBRARY_DIR=${YAML_ROOT}/lib"
    )
fi

if [[ "${CLEAN}" = "1" ]]; then
    rm -rf "${BUILD_PATH}"
fi

mkdir -p "${BUILD_PATH}"
cd "${BUILD_PATH}"

cmake "${CMAKE_OPTIONS[@]}" "${SCRIPT_DIR}"
make -j "${JOBS}"

echo "Build complete: ${BUILD_PATH}/AMCA3D"
