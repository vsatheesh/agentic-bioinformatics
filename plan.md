# Plan

The idea behind this repo is to watch how AI coding agents handle real
bioinformatics work. To do that we need something to check their answers
against. That's what the two pipelines are for: the same variant calling job
written twice, once in Snakemake and once in Nextflow. If both give the same
answer on the same data, we can trust that answer, and we can score whatever
an agent produces against it.

The work below is in the order it has to happen. The first three parts are
just getting the pipelines into shape. The study itself comes last.

## Where things stand

Both pipelines now do the same five steps: trim the reads, index the genome,
align and sort, index the BAM, call variants. The step names differ (rules in
Snakemake, processes in Nextflow) but they line up one to one.

Neither pipeline has actually been run yet. Everything below is untested.

## First: get one run to finish

Five things are in the way, roughly in the order you'll hit them.

The Nextflow side pulls in six module files that aren't in the repo: fastp,
the two indexing steps, the aligner, the BAM indexer, and the caller. Nothing
runs until those are committed.

Once they're there, the aligner module needs the same two flags we added to
the Snakemake version in `fe067ff` and `e2656c7`: `-K 100000000`, which stops
the alignment from changing when the thread count changes, and the `@RG` line,
which puts the sample name in the output instead of the file path. If only one
side has these, the two pipelines will disagree and it won't be either
pipeline's fault.

We also need test data committed — the 1 Mb chunk of B73 chr1 the config
already points at, plus a couple of small read pairs. Small enough to keep in
git, big enough to actually produce variants.

Then a `nextflow.config` (which machine to run on, how many cores and how much
memory each step gets), and a `.gitignore` so the work directories and outputs
don't get committed by accident.

Done when both pipelines run start to finish and produce a VCF per sample.

## Second: decide what "same answer" means

This is the part that does the real work, and it's easy to skip past.

Two VCFs from the same reads will never be byte-identical. Headers differ,
the tool records its own command line, records at the same position can come
out in a different order. None of that matters. What matters is whether the
two pipelines found the same variants in the same places.

So we need a small script that tidies both files up the same way and then
compares just the variant lists. Run it on the output from the previous step
and keep fixing things until it comes back clean. If something still differs,
one of the two pipelines is wrong, and we need to know that before going any
further. This is the step that lets the README say "cross-validated" and mean
it.

Whatever both pipelines agree on becomes the reference. That's what agent runs
get scored against later.

Done when the script passes and the reference files are saved.

## Third: pin the versions

Right now both pipelines just say `module load bwa_mem2` and so on, with no
version. That means they pick up whatever the cluster happens to have that
day, and that changes over time. For a study meant to be repeatable, that's a
problem. A run six months from now wouldn't be comparable to one today.

Either name the versions explicitly, or switch to conda environments or
containers. Containers are the better bet if anyone outside this cluster is
ever going to reproduce this.

While we're at it, each run should write down what it used: tool versions, the
git commit, the command. Then re-run the comparison from the previous step to
make sure pinning didn't quietly change anything.

## Fourth: the actual study

Only worth starting once the three parts above hold, since everything here is
measured against the reference files.

We need to settle on the tasks. Some rough ideas, easiest first: just run the
pipeline; find and fix a config we've broken on purpose; add a new step; take
a step from one pipeline and rewrite it in the other language.

We need somewhere to put the results — one folder per run holding the prompt,
the whole conversation, whatever the agent changed, and the output files. Runs
have to stay out of each other's way, and out of the reference copy.

We need to agree on what we're measuring. Did it produce anything? Do the
variants match the reference? How long did it take, and how many rounds of
back and forth? Did it wander off and edit files it shouldn't have touched?
And the one really worth watching for: did it quietly weaken the pipeline to
make the errors go away.

Agents don't give the same answer twice, so one run per task tells us nothing.
Pick a number of repeats up front.

## Things we still need to decide

- How close do the two pipelines have to be? Same list of variants, or do the
  quality and depth numbers have to match too? Strict matching might not be
  achievable if the two callers are set up even slightly differently.
- Which agents are we testing, and how do we drive them?
- How many repeats per task?
- Do agents get to see both pipelines, or only one? Showing both gives away
  the answer for the rewrite task.
- Can the genome slice be shared publicly, or does the test data need to be
  downloaded by a script instead of committed?
