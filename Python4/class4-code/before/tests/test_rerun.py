"""A rerun of the same batch must not repeat business work. Starter stub for Section 8."""
 
 
def test_rerun_same_batch_does_not_duplicate(settings_for, data_dir):
    """Promise: a second run of the same batch makes no new model calls and writes no second result.
    Use a fake caller that counts its calls and returns one valid JSON reply.
    Run run_batch() twice with the same settings. Assert: the call count does not change after the second run,
    the batch_id is the same, there is exactly one batch folder, and attempts.log has two lines."""
    assert False, "TODO (Section 8): write test_rerun_same_batch_does_not_duplicate"
