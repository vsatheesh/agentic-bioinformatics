# Plan

We want to see how AI coding agents handle real bioinformatics work. To grade
them we need a right answer to grade against. That's what the two pipelines
are for: the same variant calling job written twice, once in Snakemake and
once in Nextflow. If both give the same answer on the same data, we trust that
answer, and we score the agents against it.

Steps are in the order they have to happen. The study itself comes last.

## Where things stand

- Both pipelines do the same five steps: trim the reads, index the genome,
  align and sort, index the BAM, call variants.
- The names differ (rules in Snakemake, processes in Nextflow) but they match
  up one to one.
- That's the shape matching, not the behaviour. What each step actually does
  comes down to the flags it runs with, and on the Nextflow side those sit in
  the module files that aren't committed yet. So we can't say yet that the two
  really do the same thing.
- Neither pipeline has been run yet. Everything below is untested.

## Step 1: get one run to finish

- Commit the six Nextflow module files. They're referenced but missing, so
  nothing runs without them.
- Copy the two flags we added to the Snakemake aligner in `fe067ff` and
  `e2656c7` into the Nextflow aligner module:
  - `-K 100000000`, so the alignment doesn't change when the thread count
    changes.
  - the `@RG` line, so the sample name ends up in the output instead of the
    file path.
  - If only one side has these, the two pipelines will disagree and it won't
    be either pipeline's fault.
- Match the rest of the settings the same way once the modules are visible:
  - fastp: the Snakemake rule runs on defaults, so whatever quality and length
    settings the Nextflow module uses need copying over, or both sides need
    setting on purpose.
  - bcftools mpileup: called with no options on the Snakemake side, so its
    default depth cap and annotations have to match too.
- Commit test data: the 1 Mb piece of B73 chr1 the config already points at,
  plus a couple of small read pairs. Small enough for git, big enough to give
  real variants.
- Add a `nextflow.config`: where to run, and cores and memory per step. Use
  the same core counts as the Snakemake rules. Snakemake asks for 4 threads,
  so Nextflow should ask for 4, not just some number. `samtools sort -@` can
  reorder records sitting at the same position, and fastp's `-w` changes its
  output, so these have to line up.
- Add a `.gitignore` so work folders and outputs don't get committed.

Done when both pipelines run start to finish and give one VCF per sample.

## Step 2: decide what "same answer" means

- Two VCFs from the same reads are never identical byte for byte. Headers
  differ, the tool writes its own command line into the file, and records at
  the same position can come out in a different order.
- None of that matters. What matters is whether both found the same variants
  in the same places.
- Before comparing the two against each other, check each one against itself:
  run it twice on the same input and compare. If a pipeline can't reproduce
  its own output, comparing it to the other one tells us nothing.
- Write a small script that cleans up both files the same way and compares
  just the variant lists.
- Run it and keep fixing until it comes back clean. Anything left over means
  one of the pipelines is wrong, and we need to know that now.
- Save what both pipelines agree on. That's the reference the agents get
  scored against.
- Compare at every step, not just the final VCF. Checksum the trimmed reads,
  the sorted BAMs and the calls separately. Comparing only the end tells us
  that they differ; comparing each step tells us where, which is the
  difference between a quick fix and a day of guessing.
- Do this on at least two samples. One sample can agree by luck.
- Keep the intermediate BAMs. When an agent's output is wrong later, these
  show which step it went wrong at.

Done when the script passes and the reference files are saved.

## Step 3: pin everything down

- Both pipelines say `module load bwa_mem2` and so on with no version, so they
  pick up whatever the cluster has that day. Name the versions, or move to
  conda or containers. Containers are the better bet if anyone off this
  cluster will ever repeat this.
- Pin the agents the same way. Model versions change under the same name, so
  write down the exact version and the date for every run.
- Have each run record what it used: tool versions, model version, git commit,
  and the command.
- Re-run the Step 2 comparison afterwards to check that pinning didn't change
  anything.

## Step 4: build the tasks

This is the part of the study we're actually changing between runs, and none
of it exists yet.

- Write a set of faults to seed, each saved as a patch with its correct fix
  written down. Rough ideas:
  - a wrong path in the config
  - a rule whose output name doesn't match what the next rule expects
  - a missing genome index
  - R1 and R2 swapped
  - a memory limit too low to finish
- Add a few tasks that aren't bug fixes: run the pipeline as given, add a new
  step, rewrite a step from one language in the other.
- Keep the answers out of reach. Right now the commit message on `e2656c7`
  explains the thread-count problem, and this file spells it out again. An
  agent that reads the git log or opens this file has been handed the answer.
  - Give each run a clean copy with history that doesn't discuss the bug.
  - Keep the reference VCFs out of the agent's working folder.
- Decide when a run is over: the agent says it's done, or a turn limit, or a
  time limit. If runs end whenever, the timing numbers mean nothing.

## Step 5: run the study

Written up in more detail in `plan_agent_runs.md`.

- One folder per run holding the prompt, the whole conversation, whatever the
  agent changed, and the output files. Runs stay out of each other's way and
  out of the reference copy.
- Pick a control to compare against: a person doing the same tasks under the
  same limit, or an agent that can edit but not run anything. Without one we
  can describe what agents did but can't say whether it was any good.
- Measure:
  - did it produce anything at all
  - do the variants match the reference
  - tokens and cost (a better measure of effort than wall clock, which on the
    cluster is mostly queue time)
  - how many rounds of back and forth
  - did it edit files it shouldn't have touched
  - did it quietly weaken the pipeline to make the errors go away
- Agree on how the diffs get read, and by whom. A short list of failure types
  helps: hardcoded a path, deleted the failing step, weakened a filter, fixed
  the symptom not the cause, gave up. If two people score, check they agree.
- Agents don't give the same answer twice, so one run per task tells us
  nothing. Pick the number of repeats up front.
- Keep a second dataset the tasks were never tuned on, to tell a real fix from
  one that only works on the sample it was built against.
- Write down what we expect to happen and how we'll analyse it before
  collecting anything, then leave it alone.

## Still to decide

- How close do the pipelines have to be? Same list of variants, or do the
  quality and depth numbers have to match too? Strict matching may not be
  possible if the two callers differ even slightly in their defaults.
- Which agents, and how do we drive them?
- How many repeats per task?
- Do agents see both pipelines or only one? Showing both gives away the answer
  for the rewrite task.
- Can the genome piece be shared publicly, or does the test data need a
  download script instead?
