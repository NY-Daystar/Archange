# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

### Project releases

## 1.9.3 - January 6th, 2026 - new features

### Added

-   exclude multiple folders with `EXCLUDE_LIST` option when using `sync` and `bysinc`
-   Can use `--duplicate` to check duplicate files into a folder

### Changed

-   Detection of invalid configuration

### Fixed

-   Handle errors with `--bisync` with wrong destination path

## 1.9.2 - January 5th, 2026 - corrections

### Added

-   Log file with `--sync` and `--bisync` options
-   Errors file with `--sync` and `--bisync` options

### Changed

-   In settings.conf and script variable `ARCHANGE_USER` -> `USER`
-   In settings.conf and script variable `ARCHANGE_PATH` -> `DESTINATION_FOLDER`
-   In settings.conf and script variable `ROOT_FOLDER_SYNC` -> `SOURCE_FOLDER`
-   In script variable `root_folder` -> `source_folder`
-   In script variable `remote_folder` -> `destination_folder`

### Fixed

-   Handle errors with `--sync` option when multiple file in source folder were deleted

## 1.9.1 - December 12th, 2025 - Add gzip

### Added

-   Include gzip option to optimize history file

## 1.9.0 - November 16th, 2025 - Sync and Bisync

### Added

-   Codacy analyzer
-   Manual page linux

### Changed

-   Can use `--sync` or `--bisync`

## 1.8.0 - October 04th, 2025 - Small fixes

### Fixed

-   repository name with spaces
-   index of repository

## 1.7.0 - August 22st, 2025 - Syncing with rclone

### Added

-   sync repository file

## 1.6.0 - February 18st, 2022 - Optimize options

### Added

-   help options

### Changed

-   Displaying history

## 1.5.0 - January 17st, 2022 - Upgrade settings editing

### Added

-   Add function name signature to all functions
-   Check if path in remote machine exists when we copy history
-   Configure default value to write settings
-   Activate debug option first before all options

## 1.4.0 - January 17st, 2022 - Upgrade settings editing

### Added

-   Add function name signature to all functions
-   Check if path in remote machine exists when we copy history
-   Configure default value to write settings
-   Activate debug option first before all options

## 1.3.0 - January 17st, 2022 - Handle history folder in config

### Added

-   Add option to show configuration file (--config)
-   Add option to edit configuration file (--setup)

## 1.2.0 - January 16st, 2022 - Handle history folder in config

### Added

-   History folder to save history

## 1.1.0 - January 15st, 2022 - Upgrade configuration setup

### Added

-   config file for configuration setup

## 1.0.0 - January 14st, 2022 - Init project
