# SPDX-License-Identifier: MPL-2.0
# Run with: ruby tests/secret_scanner_test.rb
require 'minitest/autorun'
require 'yaml'

# Configuration regression tests: no remote workflow or credentials are needed.
class SecretScannerTest < Minitest::Test
    WORKFLOW_PATH = File.expand_path('../.github/workflows/secret-scanner.yml', __dir__)
    SCANNER = 'hyperpolymath/standards/.github/workflows/secret-scanner-reusable.yml'.freeze

    def setup
        @workflow = YAML.safe_load(File.read(WORKFLOW_PATH))
        @scan = @workflow.fetch('jobs').fetch('scan')
    end

    def test_scanner_does_not_receive_caller_secrets
        # Reject both broad inheritance and explicit secret mappings, including
        # an empty mapping that could later acquire a caller secret unnoticed.
        refute @scan.key?('secrets'), 'The shared scanner must not receive caller secrets'
    end

    def test_scan_still_calls_the_pinned_shared_workflow
        workflow, revision = @scan.fetch('uses').split('@', 2)
        assert_equal SCANNER, workflow
        assert_match(/\A[0-9a-f]{40}\z/, revision)
        refute @scan.key?('steps'), 'Keep scan as a reusable workflow call'
    end

    def test_pull_requests_still_trigger_scanning_without_filters
        # Psych uses YAML 1.1 in some Ruby versions, interpreting `on` as true.
        events = @workflow.fetch('on') { @workflow.fetch(true) }
        assert events.key?('pull_request'), 'All pull requests need a scan'
        assert_nil events.fetch('pull_request'), 'Do not filter PR branches, paths, or event types'
    end

    def test_push_scanning_is_preserved_for_both_primary_branch_names
        events = @workflow.fetch('on') { @workflow.fetch(true) }
        assert_equal ['main', 'master'], events.fetch('push').fetch('branches').sort
        assert_equal ['branches'], events.fetch('push').keys
    end

    def test_scan_cannot_be_skipped_by_a_job_condition_or_dependency
        refute @scan.key?('if'), 'Removing secrets must not introduce a conditional scan'
        refute @scan.key?('needs'), 'Scanning must not depend on another job succeeding'
    end
end
