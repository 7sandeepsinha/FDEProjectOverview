""The intake vocabulary. Every problem we expect has a name, and each name has one outcome."""


class IntakeError(Exception):
    """Base class for every problem we expect while taking in a batch."""


class MalformedRecord(IntakeError):
    """One row (or one note) cannot be read. Only that record is quarantined."""


class RuleFailure(IntakeError):
    """A readable record or the whole batch breaks a business rule."""


class MissingSource(IntakeError):
    """A required file is absent. The whole run stops before any work starts."""


class UnreadableSource(IntakeError):
    """A required file exists but cannot be read as a whole, for example broken JSON."""


class QualityGateFailed(IntakeError):
    """The batch is not good enough to use. The run halts before any model call."""


class ReconciliationError(IntakeError):
    """Accepted plus quarantined does not equal the input. This is a bug in our code."""
