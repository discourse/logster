## Sample Website

This Sinatra application powers Logster's local development backend.

Start the complete development environment from the repository root:

```sh
bundle exec rake dev
```

The relevant pages are:

- `http://127.0.0.1:4200/logs/` — the Ember log viewer
- `http://127.0.0.1:9292/report_error` — the test-data laboratory

`bundle exec rake dev` enables the settings page and grouping-pattern
multi-select automatically. Direct website deployments remain opt-in through
`LOGSTER_ENABLE_CUSTOM_PATTERNS_VIA_UI=1`.

`GET /report_error` is read-only. The laboratory generates reports with bounded
`POST /report_error` batches and shows progress while creating large datasets.
It can generate mixed data or focused exception, request, database, background
job, duplicate, severity, and Unicode scenarios.

The POST endpoint also accepts JSON directly:

```sh
curl -X POST http://127.0.0.1:9292/report_error \
  -H 'Content-Type: application/json' \
  -d '{"scenario":"mixed","count":50,"seed":1234}'
```

A single request is limited to 100 reports. The browser laboratory creates
larger datasets through multiple requests so progress and cancellation remain
responsive.

Run the website tests with:

```sh
cd website
BUNDLE_GEMFILE=Gemfile bundle exec ruby -Itest test/sample_loader_test.rb
BUNDLE_GEMFILE=Gemfile bundle exec ruby -Itest test/sample_app_test.rb
```
