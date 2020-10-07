# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.6] - 2020-10-07
### Changed
- Export vars to be visible in other scripts, thanks mitjok
- Add ability to seed db, thanks mitjok
- Update deps for Elixir 1.11
- Update dialyxir version
### Fixed
- Avoid duplicate keys in the bindings passed to EEx.eval_file, thanks vimalearnest
- Pass dir as charlist to :erl_tar.extract

## [0.7.5] - 2020-02-25
### Fixed
- Fix directory creation, closes https://github.com/cogini/mix_deploy/pull/7
### Changed
- Make ex_doc dev only dependency again
- Update docs

## [0.7.4] - 2020-02-12
### Changed
- Update mix_systemd and ex_doc

## [0.7.3] - 2020-01-24
### Fixed
- Fix problem with newlines in set-env

### Changed
- Use default LANG of en_US.utf8 for better compatibility between Linux versions

## [0.7.2] - 2020-01-21
### Changed
- Updated migrate and console scripts for mix releases

## [0.7.1] - 2020-01-01
### Fixed
- Updated path to tar file, closes https://github.com/cogini/mix_deploy/pull/2

## [0.7.0] - 2020-01-01
### Added
- Support Elixir 1.9 `mix release`
- Support variable references in paths

### Removed
- Removed obsolete option flags
