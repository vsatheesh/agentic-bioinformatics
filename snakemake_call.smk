# Script 14: Variant calling (through the VCF)

configfile: "config.yaml"

GENOME = config["genome"]
SAMPLES, = glob_wildcards(config["reads_dir"] + "/{sample}_R1.fastq.gz")

rule all:
    input:
        expand(config["output_variants"] + "/{sample}.vcf", sample=SAMPLES)

rule bwa_index:
    input:
        GENOME
    output:
        multiext(GENOME, ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac")
    shell:
        """
        module load bwa_mem2
        bwa-mem2 index {input}
        """

rule faidx:
    input:
        GENOME
    output:
        GENOME + ".fai"
    shell:
        """
        module load samtools
        samtools faidx {input}
        """

rule bwa_map:
    input:
        r1 = config["output_trim"] + "/{sample}_R1.trimmed.fastq.gz",
        r2 = config["output_trim"] + "/{sample}_R2.trimmed.fastq.gz",
        genome = GENOME,
        idx = multiext(GENOME, ".0123", ".amb", ".ann", ".bwt.2bit.64", ".pac")
    output:
        config["output_aligned"] + "/{sample}.sorted.bam"
    threads: 4
    resources:
        mem_mb = 8000,
        runtime = 60
    log:
        "logs/bwa_map/{sample}.log"
    shell:
        """
        module load bwa_mem2
        module load samtools
        bwa-mem2 mem -t {threads} {input.genome} {input.r1} {input.r2} 2> {log} | samtools sort -@ {threads} -o {output}
        """

rule bam_index:
    input:
        config["output_aligned"] + "/{sample}.sorted.bam"
    output:
        config["output_aligned"] + "/{sample}.sorted.bam.bai"
    shell:
        """
        module load samtools
        samtools index {input}
        """

rule call:
    input:
        bam = config["output_aligned"] + "/{sample}.sorted.bam",
        bai = config["output_aligned"] + "/{sample}.sorted.bam.bai",
        genome = GENOME,
        fai = GENOME + ".fai"
    output:
        config["output_variants"] + "/{sample}.vcf"
    log:
        "logs/call/{sample}.log"
    shell:
        """
        module load bcftools
        bcftools mpileup -f {input.genome} {input.bam} 2> {log} | bcftools call -mv -Ov -o {output}
        """
