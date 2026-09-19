# agentic-bioinformatics-test

> Status: harness under construction. Nothing here has been run or validated yet.

A controlled study of how AI coding agents cope with real bioinformatics work:
fixing broken pipelines, adding steps, and porting a step from one workflow
language to another.

## The idea

To score an agent's work we need a right answer to score against. We get that
answer from simulated data. We build a small reference genome region, spike in a
known set of variants, and simulate sequencing reads from it. The list of
variants we put in is the truth. A pipeline's output is judged by how much of
that truth it recovers and how much it makes up.

## Why two pipelines

The same variant-calling job is written twice, once in Snakemake and once in
Nextflow. This is not how we check correctness. Two engines running the same
tools with the same settings will agree by construction, so agreement only tells
us the pipelines are reproducible, not that the calls are right. The truth set
does correctness.

The two pipelines earn their place in other ways:

- one of the agent tasks is to port a step from Snakemake to Nextflow or back,
  so we need both
- running each pipeline twice and diffing the output is our determinism check
- if the two ever disagree on the same data, something is genuinely wrong and we
  want to know before the study starts

## How this differs from other agent benchmarks

- Grading is deterministic. We compare variant lists against a validated
  reference. There is no LLM acting as judge.
- Each seeded fault comes with the correct fix written down, so we can compare
  what the agent did against a known-good patch, not just pass or fail it.
- We measure whether the agent quietly weakened the pipeline to make errors go
  away, and treat that as a first-class result.
- The pipelines run on an HPC cluster with `module load` and unpinned tool
  versions, queue time, and memory limits. That is what bioinformatics work
  actually looks like, and notebook benchmarks skip it.

## Layout

- `snakemake_call.smk`, `config.yaml` — the Snakemake pipeline
- `nextflow_call.nf`, `modules/`, `nextflow.config` — the Nextflow pipeline
- `test_genome/` — the reference region
- `data/simulate/` — builds the truth variants and simulates reads
- `01_data/` — simulated read pairs, one set per sample
- `scripts/` — comparison and checking tools
- `envs/bioinfo.yaml` — pinned tool versions for local runs
- `DESIGN.md` — the study design and where each step stands

## Running it

Build the tool env once (needs a working conda or mamba):

```
mamba env create -f envs/bioinfo.yaml
mamba activate agentic-bioinfo
```

Then rebuild the reads and run the whole check:

```
data/simulate/simulate_reads.sh     # rebuilds 01_data/ from the truth VCFs
scripts/verify_all.sh               # runs both pipelines and every check
```

To run one pipeline on its own into its own folder:

```
scripts/run_pipeline.sh snakemake runs/smk
scripts/run_pipeline.sh nextflow  runs/nf
```

On ISU HPC, `module load` the tools instead of the conda env. See `DESIGN.md`.
