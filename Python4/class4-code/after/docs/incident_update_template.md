# Incident update: <batch id>
 
Use this template when a batch halts, runs with a degraded result, or finishes with rows that need a person.
Write the facts first. Put every guess under "Not yet known", and label it as a guess.
 
**Summary (one or two sentences):** what stopped, and what it means for the people who use the report.
 
**Status:** Halted / Degraded / Complete
 
**Time of this update:** <date and time, with time zone>
 
**Batch:** <batch id> for <batch date>. Attempt: <attempt id from attempts.log>
 
## Facts
 
- What the logs and files show, with times.
- Which check stopped the run, and the exact message.
 
## Affected counts
 
| Count | Value | What it counts |
| --- | --- | --- |
| Input rows | | Rows read from each source file |
| Accepted | | Rows used in the report |
| Quarantined | | Rows set aside, by category |
| Suggestions produced | | Model answers with status OK |
| Suggestions unavailable | | Status UNAVAILABLE, with the reason |
| Published | | Reports released to users |
 
## Operational impact
 
What people cannot do today, and what they can still do.
 
## Required action
 
- Owner:
- Action:
- By when:
 
Do not rerun until the action is complete, unless the owner has said so. A rerun on the same files
gives the same halt.
 
## Not yet known
 
Questions that are still open, and any guesses, each labelled as a guess.
 
## Next update
 
<time of the next update, or the event that will trigger it>
