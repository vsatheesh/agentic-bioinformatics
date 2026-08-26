# Plan: running the workflows with a model

This is the part of the study where a model does the work instead of us.
`plan.md` covers getting the two pipelines to the point where we trust them.
This one covers what happens after that.

## Don't start until

- Both pipelines run start to finish.
- The comparison script passes and the reference files are saved.
- Tool and model versions are pinned.
- Before that there's nothing to score against, so any result is noise.

## What one run looks like

- A fresh copy of the repo at a fixed commit, one per run.
- A written prompt, the same one every time for that task.
- The model works until it says it's done or hits a limit.
- Everything it did gets saved.
- Its output gets compared to the reference.

## Setting up the sandbox

- One folder per run, nothing shared between runs.
- The reference files live outside that folder. The model must not be able to
  read the answer.
- Give each copy a clean git history. Right now the commit messages and
  `plan.md` both explain the fixes we might seed as faults.
- Decide what the model is allowed to do. These are different experiments,
  so pick one per condition and write it down:
  - edit files only
  - edit and run things locally
  - edit and submit jobs to the cluster
- Put caps on it: a limit on turns, a limit on wall clock, and a limit on how
  many cluster jobs it can submit. An agent stuck in a loop on a shared
  cluster is everyone's problem.
- No internet access, so it can't pull a working pipeline from somewhere else.

## Tasks, easiest first

- Task 0: run both pipelines as given, nothing broken. This doubles as the
  test of our own setup. If the plumbing can't handle this, nothing else
  matters.
- Task 1: the same, but with a fault seeded in.
- Task 2: add a step, say a QC summary.
- Task 3: take a step from one pipeline and write it in the other language.

Do task 0 first with one model and one repeat, all the way through, and fix
the harness before building out anything else.

## The prompt

- Fixed wording per task, saved with the run.
- Decide up front how much help it gets. Does it get told which cluster, which
  modules exist, where the data sits? Put that in the prompt rather than
  answering mid-run, or the runs stop being comparable.
- If the model asks a question, decide beforehand whether we answer at all,
  and give the same answer every time.

## What to save from each run

- the prompt
- the whole conversation
- the diff of what it changed
- the files it produced, and the logs
- model name, version and date
- tokens used and cost
- how it ended: finished, gave up, hit a limit, crashed
- time taken, remembering that on the cluster most of that is queue time

## Scoring

- Automatic first: did it produce the VCFs, and do they match the reference.
- Then read the diff by hand against the failure list in `plan.md`: hardcoded
  a path, deleted the failing step, weakened a filter, fixed the symptom
  instead of the cause, gave up.
- Score blind where we can, so the scorer doesn't know which model wrote it.
- A run can match the reference and still be a bad fix. Both things get
  recorded.

## Still to decide

- Which models, and how many repeats each.
- Does the model get to run commands at all, or only edit files?
- Does it see both pipelines or just one?
- Do we answer its questions mid-run?
- Does it get handed the logs from a failed run, or does it have to run
  things itself to find out what went wrong?
