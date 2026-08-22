#!/usr/bin/env nextflow

//-- Configurable params
params.reads           = '01_data/*_{R1,R2}.fastq.gz'
params.genome          = 'test_genome/b73_chr1_150000001-151000000.fasta'
params.output_trim        = '03_trimmed'
params.output_index       = '07_index'
params.output_bwamemindex = params.output_index   // BwaMem2Index module publishes here
params.output_aligned     = '08_aligned'      // sorted BAMs + .bai
params.output_variants    = '09_variants'     // per-sample VCFs

include { Fastp }            from './modules/fastp.nf'
include { BwaMem2Index }     from './modules/bwamem_index.nf'
include { SamtoolsFaidx }    from './modules/samtools_faidx.nf'
include { BwaMem2AlignSort } from './modules/bwamem_align_sort.nf'
include { SamtoolsIndex }    from './modules/samtools_index.nf'
include { BcftoolsCall }     from './modules/bcftools_call.nf'

// The complete pipeline, extended to variant calling:
//   raw reads -> fastp -> bwa-mem2 mem | samtools sort -> samtools index -> bcftools call -> VCF
// The reference is prepared once (bwa-mem2 index + samtools faidx) and reused by every sample.
workflow {
    // --- Reference channels (prepared once, reused by all samples) ---
    genome_ch = Channel.fromPath(params.genome, checkIfExists: true)
    index_ch  = BwaMem2Index(genome_ch)      // tuple(genome, index_files)
    faidx_ch  = SamtoolsFaidx(genome_ch)     // tuple(genome, genome.fai)

    // --- Per-sample: trim ---
    read_pairs_ch = Channel.fromFilePairs(params.reads, flat: true, checkIfExists: true)
    trimmed_ch    = Fastp(read_pairs_ch)     // tuple(sample_id, R1.trimmed, R2.trimmed)

    // --- Align (mem | sort) -> sorted BAM ---
    // combine attaches the single reference-index tuple to every sample tuple:
    //   (sample_id, R1, R2) + (genome, index_files) -> (sample_id, R1, R2, genome, index_files)
    align_input_ch = trimmed_ch.combine(index_ch.first())
    sorted_bam_ch  = BwaMem2AlignSort(align_input_ch)   // tuple(sample_id, sorted.bam)

    // --- Index the sorted BAM ---
    indexed_bam_ch = SamtoolsIndex(sorted_bam_ch)       // tuple(sample_id, bam, bai)

    // --- Call variants ---
    // attach the reference + .fai to every indexed-BAM tuple:
    //   (sample_id, bam, bai) + (genome, fai) -> (sample_id, bam, bai, genome, fai)
    call_input_ch = indexed_bam_ch.combine(faidx_ch.first())
    BcftoolsCall(call_input_ch)              // tuple(sample_id, sample_id.vcf)
}
