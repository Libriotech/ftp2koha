# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2018-05-28
### Added
- Some sample/dev data in data/
- Run once: sudo koha-mysql kohadev < data/setup.sql
- Import the record in record.marcxml
- Remove the record and item with sudo koha-mysql kohadev < data/reset.sql
- New config variable: "frameworkcode"

### Changed
- ftp2koha.pl must now be run through koha-shell or similar

### Removed
- Config variables "bulkmarcimport_path" and "koha_site"
